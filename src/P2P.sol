// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
interface IGift {
   function makeTransferByP2P(address _buyer, uint256 _orderId) external;
}
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
    address public giftContract;

    event OrderCreated(uint256 indexed orderId, address indexed seller, uint256 tokenAmount, uint256 expectedFiatAmount);
    event OrderLocked(uint256 indexed orderId, address indexed buyer, address indexed seller);
    event OrderCancelled(address indexed seller, uint256 indexed orderId);
    event OrderCompleted(address indexed seller, uint256 indexed orderId);
    event OrderReceived(address indexed seller, address indexed buyer, uint256 indexed orderId);


    function setGiftContract(address _giftContract) public {
        require(_giftContract != address(0));
        require(giftContract == address(0));
        giftContract = _giftContract;
    }
   function createOrder(address _seller, uint256 _tokenAmount,  string memory _accountName, string memory _accountNumber, string memory _bankName) external {
        require(activeOrderId[_seller] == 0, "Seller already has an active order. Please complete or cancel it before creating a new one.");
        orderCount++;
        orders[orderCount] = Order({
            seller: _seller,
            buyer: address(0),
            tokenAmount: _tokenAmount,
            expectedFiatAmount: 0,
            accountName: _accountName,
            accountNumber: _accountNumber,
            bankName: _bankName,
            status: OrderStatus.Open
        });
        activeOrderId[_seller] = orderCount;
        emit OrderCreated(orderCount, _seller, _tokenAmount, _tokenAmount*1450);
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
        order.expectedFiatAmount = order.tokenAmount * publicbuyers[_buyer].unitPrice;

        // Alert buyer
            buyerPendingTrans[_buyer].push(_orderId);
        emit OrderLocked(_orderId, _buyer, _seller);
    }
    function cancelOrder(address _user, uint256 _orderId) external {
        Order storage order = orders[_orderId];
        if(order.status == OrderStatus.Open){
            require(order.seller == _user, "Only the seller can cancel the order");
        }else if(order.status == OrderStatus.Locked){
            require(order.buyer == _user, "Only the buyer can cancel the order");

        }
        else{
            revert("Order cannot be cancelled at this stage");
        }

        order.status = OrderStatus.Cancelled;
        //Delete order from buyer's pending transactions if it was locked        if(order.status == OrderStatus.Locked){
            uint256[] storage pendingOrders = buyerPendingTrans[order.buyer];
            for(uint256 i = 0; i < pendingOrders.length; i++){
                if(pendingOrders[i] == _orderId){
                    pendingOrders[i] = pendingOrders[pendingOrders.length - 1];
                    pendingOrders.pop();
                    break;
                }
            }
            // Clear active order for the seller
        activeOrderId[order.seller] = 0; // Clear active order for the seller
        emit OrderCancelled(order.seller, _orderId);
    }

    function completeOrder(address _buyer, uint256 _orderId) external {
        // Only the buyer can complete the order
        Order storage order = orders[_orderId];
        require(order.buyer == _buyer, "Only the buyer can complete the order");
        if(order.status == OrderStatus.Locked){
            order.status = OrderStatus.Completed;
        }
        emit OrderCompleted(_buyer, _orderId);
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

            IGift(giftContract).makeTransferByP2P(order.buyer, _orderId);
            activeOrderId[order.seller] = 0; // Clear active order for the seller
            emit OrderReceived(_seller, _buyer, _orderId);
        }
    }
    function getOrder(uint256 _orderId) external view returns (Order memory) {
        return orders[_orderId];
    }
    function getBuyerPendingOrders(address _buyer) external view returns (uint256[] memory) {
        return buyerPendingTrans[_buyer];
    }   
    
    function getAllBuyers(uint256 offset, uint256 limit) external view returns (BuyerInfo[] memory) {
        uint256 total = allBuyers.length;
        if (offset >= total) {
            return new BuyerInfo[](0);
        }

        uint256 end = offset + limit > total ? total : offset + limit;
        uint256 size = end - offset;
        BuyerInfo[] memory result = new BuyerInfo[](size);

        for (uint256 i = 0; i < size; i++) {
            result[i] = allBuyers[offset + i];
        }
        
        return result;
    }
    function getBuyerCount() external view returns (uint256) {
        return allBuyers.length;
    }
    function getActiveOrderId(address _seller) external view returns (uint256) {
        return activeOrderId[_seller];
    }
    function getBuyerInfoByAddress(address _buyer) external view returns (BuyerInfo memory) {
        return publicbuyers[_buyer];
    }
    function changeBuyerStatus(address _buyer) external {
        require(publicbuyers[_buyer].buyerAddress != address(0), "Buyer does not exist");
        publicbuyers[_buyer].buyerStatus = !publicbuyers[_buyer].buyerStatus;
    }
}