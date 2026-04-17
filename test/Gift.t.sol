// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Gift.sol";
import "../src/Users.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// A simple Mock ERC20 Token to use for testing
contract MockToken is ERC20 {
    constructor() ERC20("Mock Token", "MTK") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract GiftTest is Test {
    Gift public gift;
    Users public users;
    MockToken public token;

    address public deployer = address(this);
    address public alice = address(1);
    address public bob = address(2);

    event GiftSent(address indexed from, address indexed to, uint256 amount);
    event GiftClaimed(address indexed by, uint256 amount);

    function setUp() public {
        // 1. Deploy contracts
        users = new Users();
        token = new MockToken();
        gift = new Gift(address(users), address(token));

        // 2. Register Test Users
        vm.prank(alice);
        users.addUser("alice", "Alice", "alice@example.com");

        vm.prank(bob);
        users.addUser("bob", "Bob", "bob@example.com");

        // 3. Mint tokens to Bob and Alice to use for testing
        token.mint(bob, 1000 ether);
        token.mint(alice, 1000 ether);

        // 4. Pre-approve the Gift contract to spend tokens on their behalf
        vm.prank(bob);
        token.approve(address(gift), type(uint256).max);
        
        vm.prank(alice);
        token.approve(address(gift), type(uint256).max);
    }

    function testConstructorRevertsOnZeroAddress() public {
        vm.expectRevert("Users contract address cannot be zero");
        new Gift(address(0), address(token));

        vm.expectRevert("Token address cannot be zero");
        new Gift(address(users), address(0));
    }

    function testGiftUserSuccess() public {
        uint256 giftAmount = 100 ether;

        vm.prank(bob);
        vm.expectEmit(true, true, false, true);
        emit GiftSent(bob, alice, giftAmount);
        
        gift.giftUser("alice", giftAmount);

        // Validate State Changes
        assertEq(gift.pendingGifts(alice), giftAmount);
        assertEq(token.balanceOf(address(gift)), giftAmount); // Contract holds the funds
        assertEq(token.balanceOf(bob), 1000 ether - giftAmount); // Bob's balance decreased
    }

    function testGiftUserRevertUserNotFound() public {
        vm.prank(bob);
        vm.expectRevert("User not found");
        gift.giftUser("charlie", 100 ether); // 'charlie' doesn't exist
    }

    function testGiftUserRevertRecipientNotActive() public {
        // Deactivate Alice
        users.makeInactive("alice");

        vm.prank(bob);
        vm.expectRevert("Recipient user is not active");
        gift.giftUser("alice", 100 ether);
    }

    function testGiftUserRevertInsufficientFunds() public {
        vm.prank(bob);
        vm.expectRevert("Insufficient funds for the specified amount");
        gift.giftUser("alice", 2000 ether); // Bob only has 1000
    }

    function testClaimGiftByCrptoSuccess() public {
        // 1. Bob sends Alice a gift of 200
        vm.prank(bob);
        gift.giftUser("alice", 200 ether);

        assertEq(gift.pendingGifts(alice), 200 ether);

        // 2. Alice claims 50
        vm.prank(alice);
        vm.expectEmit(true, false, false, true);
        emit GiftClaimed(alice, 50 ether);
        gift.claimGiftByCrpto(50 ether);

        // 3. Verify final states
        assertEq(gift.pendingGifts(alice), 150 ether); // Remaining pending
        assertEq(token.balanceOf(alice), 1050 ether); // Alice's wallet balance increased by 50
        assertEq(token.balanceOf(address(gift)), 150 ether); // Contract still holds the remaining 150
    }

    function testClaimGiftRevertPaused() public {
        // 1. Bob gifts Alice
        vm.prank(bob);
        gift.giftUser("alice", 100 ether);

        // 2. Owner pauses the Users contract
        users.pause();
        assertTrue(users.isItPaused());

        // 3. Alice attempts to claim
        vm.prank(alice);
        vm.expectRevert("Contract is paused");
        gift.claimGiftByCrpto(100 ether);
    }

    function testClaimGiftRevertNoPendingGifts() public {
        vm.prank(alice); // Alice has 0 pending gifts
        vm.expectRevert("No pending gifts to claim");
        gift.claimGiftByCrpto(50 ether);
    }

    function testClaimGiftRevertInsufficientPendingAmount() public {
        vm.prank(bob);
        gift.giftUser("alice", 100 ether);

        vm.prank(alice);
        vm.expectRevert("Insufficient pending gift amount");
        gift.claimGiftByCrpto(200 ether); // Alice tries to claim more than she was gifted
    }
}
