// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract P2P{


    struct Order {
        address seller;             // Wants Fiat, providing Crypto
        address buyer;              // Wants Crypto, providing Fiat
        uint256 tokenAmount;        // Amount of crypto locked
        uint256 expectedFiatAmount;  // e.g., "100 USD"
        string accountName;
        string accountNumber;
        string bankName;      
        OrderStatus status;
    }
    enum OrderStatus { Open, Locked, Completed, Cancelled }

    struct BuyerInfo {
        address buyerAddress;
        string buyerName;
        uint256 unitPrice; 
        uint256 totalOrders;
        uint256 totalVolume;
        uint256 rank;
        bool buyerStatus;
    }
    BuyerInfo[] public allBuyers;
    mapping(address => BuyerInfo) publicbuyers;
    mapping(uint256 => Order) public orders;
    uint256 public orderCount;
    mapping(address => uint256) public activeOrderId; 
    mapping(address => uint256) public buyerPendingTrans;

   function createOrder(address _seller, uint256 _tokenAmount,  string memory _accountName, string memory _accountNumber, string memory _bankName) external {
        orderCount++;
        orders[orderCount] = Order({
            seller: _seller,
            buyer: address(0),
            tokenAmount: _tokenAmount,
            expectedFiatAmount: _tokenAmount*1450,
            accountName: _accountName,
            accountNumber: _accountNumber,
            bankName: _bankName,
            status: OrderStatus.Open
        });
        activeOrderId[_seller] = orderCount;
    }
function addNewBuyer(address _buyer, string memory _buyerName, uint256 unitPrice) external {
        require(_buyer != address(0), "Buyer address cannot be zero");
        require(unitPrice > 0, "Unit price must be greater than zero");
        require(bytes(_buyerName).length > 0, "Buyer name cannot be empty");
        BuyerInfo memory buyerInfo = BuyerInfo({
            buyerAddress: _buyer,
            buyerName: _buyerName,
            unitPrice: unitPrice,
            totalOrders: 0,
            totalVolume: 0,
            rank: 0,
            buyerStatus: true
        });
        allBuyers.push(buyerInfo);
        publicbuyers[_buyer] = buyerInfo;
    }
    function getBuyerInfo(address _buyer) external view returns (BuyerInfo memory) {
        require(_buyer != address(0), "Buyer address cannot be zero");
        return publicbuyers[_buyer];
    }
    function lockOrder(address _seller, address _buyer, uint256 _orderId) external {
        Order storage order = orders[_orderId];
        require(order.status == OrderStatus.Open, "Order is not open");
        require(order.seller == _seller, "Only the seller can lock the order");
        order.buyer = _buyer;
        order.status = OrderStatus.Locked;

    }



}
