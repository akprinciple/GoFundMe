// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/P2P.sol";

contract MockGift is IGift {
    function makeTransferByP2P(address _buyer, uint256 _orderId) external override {}
}

contract P2PTest is Test {
    P2P public p2p;
    MockGift public mockGift;

    address public seller = address(1);
    address public buyer = address(2);

    function setUp() public {
        p2p = new P2P();
        mockGift = new MockGift();
        p2p.setGiftContract(address(mockGift));
    }

    function testSetGiftContractRevert() public {
        vm.expectRevert();
        p2p.setGiftContract(address(mockGift)); // Should revert because it's already set in setUp
    }

    function testAddBuyer() public {
        p2p.addNewBuyer(buyer, "Bob", 1500);
        assertEq(p2p.getBuyerCount(), 1);

        P2P.BuyerInfo memory info = p2p.getBuyerInfo(buyer);
        assertEq(info.buyerName, "Bob");
        assertEq(info.unitPrice, 1500);
        assertTrue(info.buyerStatus);
    }

    function testCreateOrder() public {
        vm.prank(seller);
        p2p.createOrder(seller, 100 * 1e18, "Alice Account", "1234567890", "Bank A");

        assertEq(p2p.orderCount(), 1);
        assertEq(p2p.getActiveOrderId(seller), 1);

        P2P.Order memory order = p2p.getOrder(1);
        assertEq(order.seller, seller);
        assertEq(order.tokenAmount, 100 * 1e18);
        assertTrue(order.status == P2P.OrderStatus.Open);
    }

    function testLockOrder() public {
        p2p.addNewBuyer(buyer, "Bob", 1500);
        
        vm.prank(seller);
        p2p.createOrder(seller, 100, "Alice Account", "1234567890", "Bank A");

        vm.prank(seller);
        p2p.lockOrder(seller, buyer, 1);

        P2P.Order memory order = p2p.getOrder(1);
        assertEq(order.buyer, buyer);
        assertTrue(order.status == P2P.OrderStatus.Locked);
        assertEq(order.expectedFiatAmount, 100 * 1500);

        uint256[] memory pending = p2p.getBuyerPendingOrders(buyer);
        assertEq(pending.length, 1);
        assertEq(pending[0], 1);
    }

    function testCompleteAndReceiveOrder() public {
        p2p.addNewBuyer(buyer, "Bob", 1500);
        
        vm.prank(seller);
        p2p.createOrder(seller, 100, "Alice Account", "1234567890", "Bank A");

        vm.prank(seller);
        p2p.lockOrder(seller, buyer, 1);

        vm.prank(buyer);
        p2p.completeOrder(buyer, 1);

        P2P.Order memory completedOrder = p2p.getOrder(1);
        assertTrue(completedOrder.status == P2P.OrderStatus.Completed);

        vm.prank(seller);
        p2p.receiveOrder(seller, buyer, 1);

        P2P.Order memory receivedOrder = p2p.getOrder(1);
        assertTrue(receivedOrder.status == P2P.OrderStatus.Received);
        assertEq(p2p.getActiveOrderId(seller), 0);
    }
}