// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Users} from "./Users.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Gift{
    Users public usersContract;
    IERC20 public token;
    mapping(address => uint256) public pendingGifts;

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
        pendingGifts[recipient] += _amount;

        emit GiftSent(msg.sender, recipient, _amount);
    }
   function claimGiftByCrpto(uint256 _amount) public {
        uint256 amount = pendingGifts[msg.sender];
        require(usersContract.isItPaused() == false, "Contract is paused");
        require(amount > 0, "No pending gifts to claim");
        require(amount >= _amount, "Insufficient pending gift amount");

        // Reset the pending gift amount before transferring to prevent reentrancy issues
        pendingGifts[msg.sender] = pendingGifts[msg.sender] - _amount;

        // Transfer the gift amount from the contract to the recipient
        token.transfer(msg.sender, _amount);

        emit GiftClaimed(msg.sender, _amount);
    } 
}