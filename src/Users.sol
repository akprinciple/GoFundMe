// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

contract Users {
    address public owner;
    struct User { 
        string name;
        string email;
        uint256 bal;
        bool status;
    }
    string[] public userNames;
    mapping(string => address) public usernameToAddress;
    mapping(address => string) public addressToUsername;
    mapping (address => User ) public userInfo;
    mapping(string => bool) public emailExists;
    bool public isPaused;
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }
    constructor() {
        owner = msg.sender;
    }
    function pause() public onlyOwner {
        isPaused = !isPaused;
    }
    function isItPaused() public view returns(bool) {
        return isPaused;
    }
    function addUser(string memory _username, string memory _name, string memory _email) public {
        require(usernameToAddress[_username] == address(0), "Username already exists");
        require(bytes(userInfo[msg.sender].name).length == 0, "Address already registered");
        
        require(!emailExists[_email], "Email already exists");

        userInfo[msg.sender] = User({name: _name, email: _email, bal: 0, status: true});
        userNames.push(_username);
        usernameToAddress[_username] = msg.sender;
        addressToUsername[msg.sender] = _username;
        emailExists[_email] = true;
    }
    
    function getAllUsers() public view returns(string[] memory) {
        return userNames;
    }

    function getUserByUsername(string memory _username) public view returns(string memory, uint256, bool) {
        address userAddress = usernameToAddress[_username];
        return (userInfo[userAddress].email, userInfo[userAddress].bal, userInfo[userAddress].status);
    }
    
    // Get All users whose status is true
    function getActiveUsers() public view returns(string[] memory) {
        uint256 activeCount = 0;
        for (uint256 i = 0; i < userNames.length; i++){
            address userAddress = usernameToAddress[userNames[i]];
            if(userInfo[userAddress].status){
                activeCount++;
            }
        }

        string[] memory activeUsers = new string[](activeCount);
        uint256 counter = 0;
        for (uint256 i = 0; i < userNames.length; i++){
              address userAddress = usernameToAddress[userNames[i]];
            if(userInfo[userAddress].status){
                activeUsers[counter] = userNames[i];
                counter++;
            }
        }
        return activeUsers;
    }

    function getInactiveUsers() public view returns (string[] memory) {
    uint256 totalUsers = userNames.length;
    uint256 inactiveCount = 0;

    // First Pass: Count how many are inactive to size the array perfectly
    for (uint256 i = 0; i < totalUsers; i++) {
          address userAddress = usernameToAddress[userNames[i]];
        if (userInfo[userAddress].status == false) {
            inactiveCount++;
        }
    }

    // Initialize memory array with the EXACT size needed
    string[] memory inactiveUsers = new string[](inactiveCount);
    uint256 currentIndex = 0;

    // Second Pass: Fill the array
    for (uint256 i = 0; i < totalUsers; i++) {
          address userAddress = usernameToAddress[userNames[i]];
        if (userInfo[userAddress].status == false) {
            inactiveUsers[currentIndex] = userNames[i];
            currentIndex++;
        }
    }

    return inactiveUsers; // Return outside the loop!
}
        //Make user Inactive by setting status to false
        function makeInactive(string memory _username) public onlyOwner() {
              address userAddress = usernameToAddress[_username];
            require(userAddress != address(0), "User not found");
            userInfo[userAddress].status = false;
        }
        //Make user Active by setting status to true
        function makeActive(string memory _username) public onlyOwner() {
             address userAddress = usernameToAddress[_username];
            require(userAddress != address(0), "User not found");
            userInfo[userAddress].status = true;
        }
        //delete user
        function deleteUser(string memory _username) public onlyOwner() {
            address userAddress = usernameToAddress[_username];
            require(userAddress != address(0), "User not found");

            string memory userEmail = userInfo[userAddress].email;

            for (uint256 i = 0; i < userNames.length; i++){
                if(keccak256(bytes(userNames[i])) == keccak256(bytes(_username))){
                    userNames[i] = userNames[userNames.length - 1];
                    userNames.pop();
                    break;
                }
            }
            delete emailExists[userEmail];
            delete usernameToAddress[_username];
            delete addressToUsername[userAddress];
            delete userInfo[userAddress];
        }

        
}