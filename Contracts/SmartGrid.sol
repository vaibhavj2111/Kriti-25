// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title Smart Grid System with Energy Trading and Carbon Credits
/// @author 
contract SmartGrid {

    // Structs
    struct User {
        uint256 energyBalance; // Energy in kWh
        uint256 carbonCredits; // Carbon credits owned
        bool isUser;          // User role
        Trade[] TradeList;
    }
    
    struct Trade {
        uint256 tradeId;
        address buyer;
        address seller;
        uint256 energyAmount;  // Energy in kWh
        uint256 price;        // Price in wei
        uint status;          // 0-rejected 1-UnderProcess 2-Completed
    }

    // Mappings
    mapping(address => User) public users;
    Trade[] public trades; // Global Trades- consists of all the trades
    uint256 public totalUsers = 0;

    // Events
    event userAdded(address userAddress);
    event userRegistered(address userAddress, bool isExists);
    event TradeCreated(uint256 tradeId, address buyer, address seller, uint256 energyAmount, uint256 price, uint status);
    event TradeCompleted(uint256 tradeId, address buyer, address seller, uint256 energyAmount);

    // Modifiers
    modifier onlyRegisteredUser() {
        require(users[msg.sender].isUser, "User not registered");
        _;
    }

    modifier onlyProducer() {
        require(users[msg.sender].isUser, "Not authorized");
        _;
    }

    modifier hasEnoughBalance(address _user, uint256 _amount) {
        require(users[_user].energyBalance >= _amount, "Insufficient energy balance");
        _;
    }

    // Register New user
    function registerUser(address userAddress) external {
        require(!users[msg.sender].isUser, "User already exists");
        
        // Initialize a new User struct fields individually
        users[msg.sender].energyBalance = 0;
        users[msg.sender].carbonCredits = 0;
        users[msg.sender].isUser = true;
        // TradeList is automatically initialized as an empty array

        totalUsers++;
        emit userAdded(userAddress);
    }

    // Get total number of Users
    function getNoOfUser() public view returns (uint256) {
        return totalUsers;
    }

    // Producers add energy
    function produceEnergy(uint256 _energyAmount) external onlyProducer {
        users[msg.sender].energyBalance += _energyAmount;
    }

    // Get all Trades list at a single marketplace
    function getallTrades() public view returns (Trade[] memory) {
        return trades;
    }

    // Put Trade up for sale by seller
    function putTrade(uint256 _energyAmount, uint256 _price) external 
        onlyProducer 
        hasEnoughBalance(msg.sender, _energyAmount) 
    {
        trades.push(Trade({
            tradeId: trades.length,
            buyer: address(0), // No buyer yet
            seller: msg.sender,
            energyAmount: _energyAmount,
            price: _price,
            status: 0 // Trade is up for sale
        }));
        emit TradeCreated(trades.length - 1, address(0), msg.sender, _energyAmount, _price, 0);
    }

    // Request Trade from a seller
    function requestTrade(address _seller, uint256 energyAmount, uint256 price) external 
        onlyRegisteredUser 
        hasEnoughBalance(msg.sender, energyAmount)
    {
        users[_seller].TradeList.push(Trade({
            tradeId: users[_seller].TradeList.length,
            buyer: msg.sender,
            seller: _seller,
            energyAmount: energyAmount,
            price: price,
            status: 1
        }));
        emit TradeCreated(trades.length - 1, msg.sender, _seller, energyAmount, price, 1);
    }

    // Accepting the trade offer
    function acceptTrade(uint256 _tradeId) external payable onlyRegisteredUser {
        Trade storage trade = trades[_tradeId];
        require(trade.status == 1, "Trade not in correct state");  // Only accept trades that are UnderProcess
        require(trade.buyer == msg.sender, "Not authorized: Must be the buyer");
        require(msg.value == trade.price, "Incorrect payment amount");
        
        users[trade.seller].energyBalance -= trade.energyAmount;
        users[trade.buyer].energyBalance += trade.energyAmount;
        payable(trade.seller).transfer(msg.value);

        trade.status = 2; // Mark trade as Completed
        emit TradeCompleted(_tradeId, trade.buyer, trade.seller, trade.energyAmount);
    }

    // Carbon credit rewards
    function rewardCarbonCredits(address _user, uint256 _credits) external {
        require(users[_user].isUser, "Only producers can earn carbon credits");
        users[_user].carbonCredits += _credits;
    }
}