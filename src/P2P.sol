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
    enum OrderStatus { Open, Locked, Completed, Received, Cancelled }

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
    mapping(address => uint256[]) public buyerPendingTrans;

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

        // Alert buyer
            buyerPendingTrans[_buyer].push(_orderId);
    }
    function cancelOrder(address _seller, uint256 _orderId) external {
        Order storage order = orders[_orderId];
        require(order.seller == _seller, "Only the seller can cancel the order");
        require(order.status == OrderStatus.Open, "Only open orders can be canceled");
        order.status = OrderStatus.Cancelled;
    }

    function completeOrder(address _buyer, uint256 _orderId) external {
        // Only the buyer can complete the order
        Order storage order = orders[_orderId];
        require(order.buyer == _buyer, "Only the buyer can complete the order");
        if(order.status == OrderStatus.Locked){
            order.status = OrderStatus.Completed;
        }

        // // Update buyer info
        // BuyerInfo storage buyerInfo = publicbuyers[order.buyer];
        // buyerInfo.totalOrders += 1;
        // buyerInfo.totalVolume += order.tokenAmount;
    }
    function receiveOrder(address _seller, address _buyer, uint256 _orderId) external {
        // Only the seller can receive the order
        Order storage order = orders[_orderId];
        require(order.seller == _seller, "Only the seller can receive the order");
        if(order.status == OrderStatus.Completed || order.status == OrderStatus.Locked){
            order.status = OrderStatus.Received;
            // Update buyer info
            BuyerInfo storage buyerInfo = publicbuyers[order.buyer];
            buyerInfo.totalOrders += 1;
            buyerInfo.totalVolume += order.tokenAmount;

            //Remove order from buyer's pending transactions
            uint256[] storage pendingOrders = buyerPendingTrans[order.buyer];
            for(uint256 i = 0; i < pendingOrders.length; i++){
                if(pendingOrders[i] == _orderId){
                    pendingOrders[i] = pendingOrders[pendingOrders.length - 1];
                    pendingOrders.pop();
                    break;
                }
            }

            // Credit Buyer's account with tokens
            token.safeTransferFrom(gift. order.buyer, order.tokenAmount);
        }





}
