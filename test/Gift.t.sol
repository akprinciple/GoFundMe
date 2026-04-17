// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Gift} from "../src/Gift.sol";
import {Users} from "../src/Users.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// A simple Mock ERC20 token to use for testing
contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Token", "MTK") {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract GiftTest is Test {
    Gift public gift;
    Users public users;
    MockERC20 public token;

    address public owner = makeAddr("owner");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    function setUp() public {
        // 1. Deploy contracts as the 'owner'
        vm.startPrank(owner);
        users = new Users();
        token = new MockERC20();
        gift = new Gift(address(users), address(token));
        vm.stopPrank();

        // 2. Register 'alice' in the Users contract
        vm.prank(alice);
        users.addUser("alice", "Alice", "alice@mail.com");

        // 3. Register 'bob' in the Users contract
        vm.prank(bob);
        users.addUser("bob", "Bob", "bob@mail.com");

        // 4. Mint 1,000 tokens to Alice and approve the Gift contract to spend them
        token.mint(alice, 1000 ether);
        vm.prank(alice);
        token.approve(address(gift), 1000 ether);
    }

    function test_giftUser() public {
        // Alice gifts Bob 100 tokens
        vm.prank(alice);
        gift.giftUser("bob", 100 ether);

        // Verify Token balances updated
        assertEq(token.balanceOf(alice), 900 ether);
        assertEq(token.balanceOf(address(gift)), 100 ether);
        
        // Verify Bob's pending balance updated
        assertEq(gift.Balance(bob), 100 ether);

        // Verify the gift history array was appended
        (address from, uint256 amount, uint256 timestamp) = gift.giftHistory(bob, 0);
        
        assertEq(from, alice);
        assertEq(amount, 100 ether);
        console.log("Gift timestamp:", timestamp);
    }

    function test_claimGiftByCrypto() public {
        // Setup: Alice gifts Bob
        vm.prank(alice);
        gift.giftUser("bob", 100 ether);

        // Bob claims 40 tokens of his gift
        vm.prank(bob);
        gift.claimGiftByCrypto(40 ether);

        // Verify pending balance is reduced
        assertEq(gift.Balance(bob), 60 ether); // 100 - 40

        // Verify Bob actually received the ERC20 tokens
        assertEq(token.balanceOf(bob), 40 ether);
        assertEq(token.balanceOf(address(gift)), 60 ether);

        // Verify claim history
        Gift.ClaimRecord[] memory history = gift.getClaimHistory(bob);
        assertEq(history.length, 1);
        assertEq(history[0].amount, 40 ether);
        assertEq(history[0].claimType, bytes6("Crypto"));
    }

    function test_claimGiftByFiat() public {
        // Setup: Alice gifts Bob
        vm.prank(alice);
        gift.giftUser("bob", 100 ether);

        // Bob claims 50 tokens of his gift via Fiat
        vm.prank(bob);
        gift.claimGiftByFiat(50 ether);

        // Verify pending balance is reduced
        assertEq(gift.Balance(bob), 50 ether);
        
        // Token balance shouldn't change for Bob on-chain
        assertEq(token.balanceOf(bob), 0);
        assertEq(token.balanceOf(address(gift)), 100 ether); // Still locked in contract

        // Verify claim history
        Gift.ClaimRecord[] memory history = gift.getClaimHistory(bob);
        assertEq(history.length, 1);
        assertEq(history[0].amount, 50 ether);
        assertEq(history[0].claimType, bytes6("Fiat"));
    }

    function test_RevertIf_UserNotFound() public {
        vm.prank(alice);
        vm.expectRevert("User not found");
        gift.giftUser("charlie", 100 ether); // 'charlie' was never registered
    }

    function test_RevertIf_UserNotActive() public {
        // Owner deactivates Bob
        vm.prank(owner);
        users.makeInactive("bob");

        vm.prank(alice);
        vm.expectRevert("Recipient user is not active");
        gift.giftUser("bob", 100 ether);
    }

    function test_RevertIf_ContractPaused() public {
        vm.prank(alice);
        gift.giftUser("bob", 100 ether);

        // Owner pauses the Users contract
        vm.prank(owner);
        users.pause();

        // Bob tries to claim
        vm.prank(bob);
        vm.expectRevert("Contract is paused");
        gift.claimGiftByCrypto(50 ether);
    }

    function test_RevertIf_InsufficientPendingGift() public {
        vm.prank(bob);
        vm.expectRevert("No pending gifts to claim");
        gift.claimGiftByCrypto(50 ether);
    }
}