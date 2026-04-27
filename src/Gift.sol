// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Users} from "./Users.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {P2P} from "./P2P.sol";
contract Gift{
    using SafeERC20 for IERC20;

    Users public immutable usersContract;
    IERC20 public immutable token;
    P2P public immutable p2pContract;
    mapping(address => uint256) public Balance;

    struct ClaimRecord {
        uint256 amount;
        bytes6 claimType;
        uint256 timestamp;
    }
    struct GiftRecord {
        address from;
        uint256 amount;
        uint256 timestamp;
    }
    mapping(address => ClaimRecord[]) public claimHistory;
    mapping(address => GiftRecord[]) public giftHistory;
    mapping(address => uint256) public hasPendingWithdrawal;
    address[] public pendingFiatWithdrawals;
    event GiftSent(address indexed from, address indexed to, uint256 amount);
    event GiftClaimed(address indexed by, uint256 amount);

    constructor(address _usersContract, address _token, address _p2pContract) {
        require(_usersContract != address(0), "Users contract address cannot be zero");
        require(_token != address(0), "Token address cannot be zero");
        usersContract = Users(_usersContract);
        token = IERC20(_token);
        p2pContract = P2P(_p2pContract);
    }

    function giftUser(string memory _username, uint256 _amount) public {
        address recipient = usersContract.usernameToAddress(_username);
        require(recipient != address(0), "User not found");
        require(usersContract.isItPaused() == false, "Contract is paused");
        require(_amount > 0, "Amount must be greater than zero");

        (,, bool isActive) = usersContract.getUserByUsername(_username);

        
        require(isActive, "Recipient user is not active");
        // Check if sender has the gross amount, even though only a portion is transferred.
        require(token.balanceOf(msg.sender) >= _amount, "Insufficient funds for the specified amount");

        // Add the amount to the recipient's pending gifts
        Balance[recipient] += _amount;
        // Record the individual gift details
        giftHistory[recipient].push(GiftRecord({
            from: msg.sender,
            amount: _amount,
            timestamp: block.timestamp
        }));

        // Transfer the gift amount into the contract (CEI pattern)
        token.safeTransferFrom(msg.sender, address(this), _amount);

        emit GiftSent(msg.sender, recipient, _amount);
    }
   function claimGiftByCrypto(uint256 _amount) public {
        uint256 amount = Balance[msg.sender];
        require(usersContract.isItPaused() == false, "Contract is paused");
        require(_amount > 0, "Amount must be greater than zero");
        require(amount > 0, "No pending gifts to claim");
        require(amount >= _amount, "Insufficient pending gift amount");
        if(hasPendingWithdrawal[msg.sender] > 0){
            revert("You have a pending withdrawal"); // Reset pending gift flag after claiming
        }
        // Reset the pending gift amount before transferring to prevent reentrancy issues
        Balance[msg.sender] = Balance[msg.sender] - _amount;

        // Record the individual claim details
        claimHistory[msg.sender].push(ClaimRecord({
            amount: _amount,
            claimType: "Crypto",
            timestamp: block.timestamp
        }));

        // Transfer the gift amount from the contract to the recipient
        token.safeTransfer(msg.sender, _amount);
         
        emit GiftClaimed(msg.sender, _amount);
    } 
    function claimGiftByFiat(uint256 _tokenAmount,  string memory _accountName, string memory _accountNumber, string memory _bankName) public {
        uint256 bal = Balance[msg.sender];
        require(usersContract.isItPaused() == false, "Contract is paused");
        require(_tokenAmount > 0, "Token amount must be greater than zero");
        require(bal > 0, "No pending gifts to claim");
        require(bal >= _tokenAmount, "Insufficient pending gift amount");
        // if(hasPendingWithdrawal[msg.sender] > 0){
        //     revert("You have a pending withdrawal"); // Reset pending gift flag after claiming
        // }
        // Reset the pending gift amount before processing the claim to prevent reentrancy issues
        Balance[msg.sender] = Balance[msg.sender] - _tokenAmount;
        token.safeApprove(address(p2pContract), _tokenAmount); // Approve P2P contract to transfer tokens on behalf of the user
        

        // Set pending gift flag until off-chain process is completed
        // hasPendingWithdrawal[msg.sender] = _tokenAmount;
        // pendingFiatWithdrawals.push(msg.sender);
         p2pContract.createOrder(msg.sender, _tokenAmount, _accountName, _accountNumber, _bankName);
       
        // Record the individual claim details
        // claimHistory[msg.sender].push(ClaimRecord({
        //     amount: _amount,
        //     claimType: "Fiat",
        //     timestamp: block.timestamp
        // }));

        emit GiftClaimed(msg.sender, _tokenAmount);
    }

    function getClaimHistory(address _user) public view returns (ClaimRecord[] memory) {
        return claimHistory[_user];
    }
    function makeTransferByP2P(address _buyer, uint256 _orderId) external {
        require(msg.sender == address(p2pContract), "Only P2P contract can call this function");
        require(p2pContract.orders[_orderId].buyer == _buyer, "Invalid buyer for this order");
        uint256 amount = p2pContract.orders[_orderId].tokenAmount;
        //transfer
        token.safeTransferFrom(address(this), _buyer, amount);
    }
    function getGiftHistory(address _user) public view returns (GiftRecord[] memory) {
        return giftHistory[_user];
    }
    function getBalance(address _user) public view returns (uint256) {
        return Balance[_user];
    }
    function getPendingWithdrawal() public view returns (uint256) {
        return hasPendingWithdrawal[msg.sender];
    }
    function cancelPendingWithdrawal() public {
        uint256 pendingAmount = hasPendingWithdrawal[msg.sender];
        require(hasPendingWithdrawal[msg.sender] > 0, "No pending withdrawal to cancel");
        hasPendingWithdrawal[msg.sender] = 0;
        Balance[msg.sender] += pendingAmount; // Return the amount back to pending gifts
    }

    // Admin function to finalize a fiat withdrawal after bank transfer is complete
    // function processFiatWithdrawal(address _user) public {
    //     require(msg.sender == usersContract.owner(), "Only owner can process fiat withdrawals");
    //     uint256 amount = hasPendingWithdrawal[_user];
    //     require(amount > 0, "No pending withdrawal to process");
    //     hasPendingWithdrawal[_user] = 0;
    //     token.safeTransfer(msg.sender, amount); // Move locked tokens to admin wallet
    // }
    function processFiatWithdrawal(address _user) public {
        require(msg.sender == usersContract.owner(), "Only owner can process fiat withdrawals");
        uint256 amount = hasPendingWithdrawal[_user];
        require(amount > 0, "No pending withdrawal to process");
        hasPendingWithdrawal[_user] = 0;
        token.safeTransfer(msg.sender, amount); // Move locked tokens to admin wallet
    }
    function getPendingFiatWithdrawals() public view returns (address[] memory) {
        return pendingFiatWithdrawals;
    }

}
