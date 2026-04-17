// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Users} from "./Users.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Gift{
    Users public usersContract;
    IERC20 public token;
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

    event GiftSent(address indexed from, address indexed to, uint256 amount);
    event GiftClaimed(address indexed by, uint256 amount);

    constructor(address _usersContract, address _token) {
        require(_usersContract != address(0), "Users contract address cannot be zero");
        require(_token != address(0), "Token address cannot be zero");
        usersContract = Users(_usersContract);
        token = IERC20(_token);
    }

    function giftUser(string memory _username, uint256 _amount) public {
        address recipient = usersContract.usernameToAddress(_username);
        require(recipient != address(0), "User not found");

        (,, bool isActive) = usersContract.getUserByUsername(_username);

        
        require(isActive, "Recipient user is not active");
        // Check if sender has the gross amount, even though only a portion is transferred.
        require(token.balanceOf(msg.sender) >= _amount, "Insufficient funds for the specified amount");

        // Transfer the gift amount into the contract
        token.transferFrom(msg.sender, address(this), _amount);


        // Add the amount to the recipient's pending gifts
        Balance[recipient] += _amount;
        // Record the individual gift details
        giftHistory[recipient].push(GiftRecord({
            from: msg.sender,
            amount: _amount,
            timestamp: block.timestamp
        }));

        emit GiftSent(msg.sender, recipient, _amount);
    }
   function claimGiftByCrypto(uint256 _amount) public {
        uint256 amount = Balance[msg.sender];
        require(usersContract.isItPaused() == false, "Contract is paused");
        require(amount > 0, "No pending gifts to claim");
        require(amount >= _amount, "Insufficient pending gift amount");

        // Reset the pending gift amount before transferring to prevent reentrancy issues
        Balance[msg.sender] = Balance[msg.sender] - _amount;

        // Record the individual claim details
        claimHistory[msg.sender].push(ClaimRecord({
            amount: _amount,
            claimType: "Crypto",
            timestamp: block.timestamp
        }));

        // Transfer the gift amount from the contract to the recipient
        token.transfer(msg.sender, _amount);

        emit GiftClaimed(msg.sender, _amount);
    } 
    function claimGiftByFiat(uint256 _amount) public {
        uint256 bal = Balance[msg.sender];
        require(usersContract.isItPaused() == false, "Contract is paused");
        require(bal > 0, "No pending gifts to claim");
        require(bal >= _amount, "Insufficient pending gift amount");

        // Reset the pending gift amount before processing the claim to prevent reentrancy issues
        Balance[msg.sender] = Balance[msg.sender] - _amount;

        // Record the individual claim details
        claimHistory[msg.sender].push(ClaimRecord({
            amount: _amount,
            claimType: "Fiat",
            timestamp: block.timestamp
        }));

        emit GiftClaimed(msg.sender, _amount);
    }

    function getClaimHistory(address _user) public view returns (ClaimRecord[] memory) {
        return claimHistory[_user];
    }
    function getGiftHistory(address _user) public view returns (GiftRecord[] memory) {
        return giftHistory[_user];
    }
}