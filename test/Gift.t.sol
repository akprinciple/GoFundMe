// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Gift.sol";
import "../src/Users.sol";
import "../src/P2P.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Token", "MTK") {}
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract GiftTest is Test {
    Users public users;
    P2P public p2p;
    Gift public gift;
    MockERC20 public token;

    address public admin = address(1);
    address public sender = address(2);
    address public recipient = address(3);

    function setUp() public {
        vm.startPrank(admin);
        users = new Users();
        p2p = new P2P();
        token = new MockERC20();
        gift = new Gift(address(users), address(token), address(p2p));
        p2p.setGiftContract(address(gift));
        vm.stopPrank();

        // Setup recipient user
        vm.prank(recipient);
        users.addUser("bob", "Bob", "bob@example.com");

        // Setup sender balance
        token.mint(sender, 1000 * 1e18);
    }

    function testGiftUser() public {
        vm.startPrank(sender);
        token.approve(address(gift), 100 * 1e18);
        gift.giftUser("bob", 100 * 1e18);
        vm.stopPrank();

        assertEq(gift.getBalance(recipient), 100 * 1e18);
        Gift.GiftRecord[] memory history = gift.getGiftHistory(recipient);
        assertEq(history.length, 1);
        assertEq(history[0].from, sender);
        assertEq(history[0].amount, 100 * 1e18);
    }

    function testClaimGiftByCrypto() public {
        vm.startPrank(sender);
        token.approve(address(gift), 100 * 1e18);
        gift.giftUser("bob", 100 * 1e18);
        vm.stopPrank();

        vm.startPrank(recipient);
        gift.claimGiftByCrypto(50 * 1e18);
        vm.stopPrank();

        assertEq(gift.getBalance(recipient), 50 * 1e18);
        assertEq(token.balanceOf(recipient), 50 * 1e18);

        Gift.ClaimRecord[] memory history = gift.getClaimHistory(recipient);
        assertEq(history.length, 1);
        assertEq(history[0].amount, 50 * 1e18);
    }

    function testClaimGiftByFiat() public {
        vm.startPrank(sender);
        token.approve(address(gift), 100 * 1e18);
        gift.giftUser("bob", 100 * 1e18);
        vm.stopPrank();

        vm.startPrank(recipient);
        gift.claimGiftByFiat(50 * 1e18, "Bob Account", "12345", "Bank");
        vm.stopPrank();

        assertEq(gift.getBalance(recipient), 50 * 1e18);
        assertEq(p2p.orderCount(), 1);
        
        P2P.Order memory order = p2p.getOrder(1);
        assertEq(order.seller, recipient);
        assertEq(order.tokenAmount, 50 * 1e18);
    }
}