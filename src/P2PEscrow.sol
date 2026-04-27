// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.20;

// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// contract P2PEscrow {
//     using SafeERC20 for IERC20;

//     IERC20 public immutable token;
//     address public immutable giftContract;

//     enum OrderStatus { Open, Locked, Completed, Cancelled }

//     struct Order {
//         address seller;             // Wants Fiat, providing Crypto
//         address buyer;              // Wants Crypto, providing Fiat
//         uint256 tokenAmount;        // Amount of crypto locked
//         string expectedFiatAmount;  // e.g., "100 USD"
//         string paymentDetails;      // e.g., "Venmo: @user"
//         OrderStatus status;
//     }

//     mapping(uint256 => Order) public orders;
//     uint256 public orderCount;

//     event OrderCreated(uint256 indexed orderId, address indexed seller, uint256 tokenAmount, string expectedFiat);
//     event OrderLocked(uint256 indexed orderId, address indexed buyer);
//     event OrderCompleted(uint256 indexed orderId, address indexed buyer);
//     event OrderCancelled(uint256 indexed orderId);

//     constructor(address _token, address _giftContract) {
//         token = IERC20(_token);
//         giftContract = _giftContract;
//     }

//     // 1. Called via Gift.sol when a user wants to withdraw to fiat
//     function createOrder(address _seller, uint256 _tokenAmount, string memory _expectedFiat, string memory _paymentDetails) external returns (uint256) {
//         require(msg.sender == giftContract, "Only Gift contract can create orders");
        
//         // Transfer tokens from the Gift contract into this Escrow
//         token.safeTransferFrom(msg.sender, address(this), _tokenAmount);

//         uint256 orderId = orderCount++;
//         orders[orderId] = Order({
//             seller: _seller,
//             buyer: address(0),
//             tokenAmount: _tokenAmount,
//             expectedFiatAmount: _expectedFiat,
//             paymentDetails: _paymentDetails,
//             status: OrderStatus.Open
//         });

//         emit OrderCreated(orderId, _seller, _tokenAmount, _expectedFiat);
//         return orderId;
//     }

//     // 2. P2P Buyer sees the open order on the frontend and commits to paying the fiat
//     function lockOrder(uint256 _orderId) external {
//         Order storage order = orders[_orderId];
//         require(order.status == OrderStatus.Open, "Order not open");
//         require(order.seller != msg.sender, "Seller cannot be buyer");

//         order.buyer = msg.sender;
//         order.status = OrderStatus.Locked;

//         emit OrderLocked(_orderId, msg.sender);
//     }

//     // 3. P2P Seller confirms they received the money off-chain and releases the crypto
//     function releaseFunds(uint256 _orderId) external {
//         Order storage order = orders[_orderId];
//         require(order.status == OrderStatus.Locked, "Order not locked");
//         require(msg.sender == order.seller, "Only seller can release funds");

//         order.status = OrderStatus.Completed;
//         token.safeTransfer(order.buyer, order.tokenAmount);

//         emit OrderCompleted(_orderId, order.buyer);
//     }

//     // 4. (Basic Cancel) - Note: In a production app, you will want a Dispute mechanism here instead!
//     function cancelOrder(uint256 _orderId) external {
//         Order storage order = orders[_orderId];
        
//         if (order.status == OrderStatus.Open) {
//             require(msg.sender == order.seller, "Only seller can cancel open order");
//         } else if (order.status == OrderStatus.Locked) {
//             require(msg.sender == order.buyer, "Only buyer can cancel locked order");
//         } else {
//             revert("Cannot cancel order in current state");
//         }

//         order.status = OrderStatus.Cancelled;
//         token.safeTransfer(order.seller, order.tokenAmount); // Return tokens to the seller

//         emit OrderCancelled(_orderId);
//     }
// }

// 2. The Traditional Escrow Pattern (Build Your Own)
// Most dApps that do P2P fiat (like LocalBitcoins, Paxful, or Binance P2P) use an Escrow Smart Contract combined with a dispute resolution system. You can easily build this alongside your Gift.sol contract.

// How it works:
// A user initiates a fiat withdrawal. The crypto is locked in an Escrow Smart Contract.
// The withdrawal is listed on a "P2P Marketplace" in your frontend.
// A "Buyer" sees the listing, clicks "Accept," and sends the fiat off-chain to the user's bank account.
// The original user verifies they received the money in their bank and clicks "Release Funds" on-chain, transferring the locked crypto to the Buyer.
// Integration: You would create an Escrow.sol contract. Instead of hasPendingWithdrawal waiting for the admin (usersContract.owner()), the funds would be locked in Escrow.sol until the seller releases them.
// 3. Decentralized Arbitration (Kleros)
// If you decide to build the Escrow Pattern, you will inevitably run into disputes (e.g., the buyer says "I sent the fiat!", but the seller says "I didn't receive it!").

// How it works: Kleros (kleros.io) is a decentralized dispute resolution protocol. They offer standard Escrow Smart Contracts that you can fork or integrate.
// Integration: If a P2P fiat trade goes wrong, either party can raise a dispute. The locked crypto is frozen, and Kleros jurors review the off-chain evidence (bank receipts) to vote on who gets the funds.
// How this changes your Gift.sol flow
// Right now, your claimGiftByFiat function subtracts the balance, flags hasPendingWithdrawal, and pushes to pendingFiatWithdrawals, waiting for the owner to call processFiatWithdrawal.

// To make it P2P, you would change claimGiftByFiat to instead:

// Deduct the user's Balance.
// Transfer the tokens to a P2PEscrow smart contract.
// Emit an event like P2POrderCreated(msg.sender, amount, fiatCurrency).
// Allow any external user (instead of just the admin) to fulfill this order through the Escrow contract.
// If you'd like to go down the route of building your own Escrow contract for this, I can help you write the Solidity code for it!