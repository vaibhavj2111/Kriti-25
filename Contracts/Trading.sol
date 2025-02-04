// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract EnergyTrading {

    struct Order {
        address user;
        uint256 quantity; // Number of energy units
        uint256 timestamp; // Order placement time for tie-breaking
    }

    // Buy and sell order buckets, indexed by price
    mapping(uint256 => Order[]) public buyOrderBuckets;
    mapping(uint256 => Order[]) public sellOrderBuckets;

    mapping(address => uint256) public balances; // User's energy balance

    uint256 public currentPrice; // Current market price of energy (updated after each trade)
    event OrderPlaced(address user, uint256 price, uint256 quantity, bool isBuyOrder);
    event OrderMatched(address buyer, address seller, uint256 price, uint256 quantity);
    event CurrentPriceUpdated(uint256 newPrice);

    constructor() {
        currentPrice = 0; // Initial market price
    }

    // Place an order (buy or sell)
    function placeOrder(uint256 price, uint256 quantity, bool isBuyOrder) external {
        require(price > 0 && quantity > 0, "Invalid order");

        if (isBuyOrder) {
            require(price >= currentPrice, "Buy price must be greater than or equal to current market price");
            buyOrderBuckets[price].push(Order(msg.sender, quantity, block.timestamp));
        } else {
            require(price <= currentPrice, "Sell price must be less than or equal to current market price");
            require(balances[msg.sender] >= quantity, "Insufficient energy balance to sell");
            sellOrderBuckets[price].push(Order(msg.sender, quantity, block.timestamp));
        }

        emit OrderPlaced(msg.sender, price, quantity, isBuyOrder);

        // Try to match the order
        matchOrders(price);
    }

    // Match orders at the exact price
    function matchOrders(uint256 price) internal {
        Order[] storage buyOrders = buyOrderBuckets[price];
        Order[] storage sellOrders = sellOrderBuckets[price];

        while (buyOrders.length > 0 && sellOrders.length > 0) {
            Order storage buyOrder = buyOrders[0];
            Order storage sellOrder = sellOrders[0];

            // Calculate trade quantity (minimum of the two orders' quantities)
            uint256 tradeQuantity = (buyOrder.quantity <= sellOrder.quantity) ? buyOrder.quantity : sellOrder.quantity;

            // Execute trade
            balances[buyOrder.user] += tradeQuantity; // Add energy to buyer's balance
            balances[sellOrder.user] -= tradeQuantity; // Deduct energy from seller's balance

            // Update the current market price to the price of the latest trade
            currentPrice = price;
            emit CurrentPriceUpdated(currentPrice);

            // Emit event for the trade
            emit OrderMatched(buyOrder.user, sellOrder.user, price, tradeQuantity);

            // Update quantities of the orders
            buyOrder.quantity -= tradeQuantity;
            sellOrder.quantity -= tradeQuantity;

            // Remove empty orders
            if (buyOrder.quantity == 0) {
                removeOrder(buyOrders, 0);
            }
            if (sellOrder.quantity == 0) {
                removeOrder(sellOrders, 0);
            }
        }
    }

    // Helper function to remove an order from a bucket
    function removeOrder(Order[] storage orders, uint256 index) internal {
        orders[index] = orders[orders.length - 1];
        orders.pop();
    }

    // Function to deposit energy into the contract
    function depositEnergy(uint256 amount) external {
        balances[msg.sender] += amount;
    }

    // Function to withdraw energy from the contract
    function withdrawEnergy(uint256 amount) external {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        balances[msg.sender] -= amount;
    }

    // Helper function to view all buy orders for a specific price
    function getBuyOrders(uint256 price) external view returns (Order[] memory) {
        return buyOrderBuckets[price];
    }

    // Helper function to view all sell orders for a specific price
    function getSellOrders(uint256 price) external view returns (Order[] memory) {
        return sellOrderBuckets[price];
    }

    // Function to get the current market price
    function getCurrentPrice() external view returns (uint256) {
        return currentPrice;
    }
}