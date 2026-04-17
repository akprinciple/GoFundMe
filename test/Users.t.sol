// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import "forge-std/Test.sol";
import "../src/users.sol";

contract UsersTest is Test {
    Users public users;

    function setUp() public {
        users = new Users();
    }

    function testAddUser() public {
        vm.prank(address(1));
        users.addUser("alice", "Alice", "alice@example.com");

        string[] memory allUsers = users.getAllUsers();
        assertEq(allUsers.length, 1);
        assertEq(allUsers[0], "alice");

        (string memory email, uint256 balance, bool status) = users.getUserByUsername("alice");
        assertEq(email, "alice@example.com");
        assertEq(balance, 0);
        assertTrue(status);
    }

    function testRevert_DuplicateUsernameAndEmail() public {
        vm.prank(address(1));
        users.addUser("alice", "Alice", "alice@example.com");

        vm.prank(address(2));
        vm.expectRevert("Username already exists");
        users.addUser("alice", "Alice2", "alice2@example.com");

        vm.prank(address(3));
        vm.expectRevert("Email already exists");
        users.addUser("alice3", "Alice3", "alice@example.com");
    }

    function testRevert_AddressAlreadyRegistered() public {
        vm.prank(address(1));
        users.addUser("alice", "Alice", "alice@example.com");

        vm.prank(address(1)); // Calling from the exact same address
        vm.expectRevert("Address already registered");
        users.addUser("alice2", "Alice2", "alice2@example.com");
    }

    function testActiveAndInactiveUsers() public {
        vm.prank(address(1));
        users.addUser("alice", "Alice", "alice@example.com");

        vm.prank(address(2));
        users.addUser("bob", "Bob", "bob@example.com");

        vm.prank(address(3));
        users.addUser("charlie", "Charlie", "charlie@example.com");

        users.makeInactive("bob");

        string[] memory active = users.getActiveUsers();
        assertEq(active.length, 2);
        assertEq(active[0], "alice");
        assertEq(active[1], "charlie");

        string[] memory inactive = users.getInactiveUsers();
        assertEq(inactive.length, 1);
        assertEq(inactive[0], "bob");
    }

    function testMakeActiveAndInactive() public {
        vm.prank(address(1));
        users.addUser("alice", "Alice", "alice@example.com");

        users.makeInactive("alice");
        (,, bool status1) = users.getUserByUsername("alice");
        assertFalse(status1);

        users.makeActive("alice");
        (,, bool status2) = users.getUserByUsername("alice");
        assertTrue(status2);
    }

    function testDeleteUser() public {
        vm.prank(address(1));
        users.addUser("alice", "Alice", "alice@example.com");
        
        vm.prank(address(2));
        users.addUser("bob", "Bob", "bob@example.com");

        users.deleteUser("alice");

        string[] memory allUsers = users.getAllUsers();
        assertEq(allUsers.length, 1);
        assertEq(allUsers[0], "bob");

        // Verify the user is removed from mapping completely
        (,, bool status) = users.getUserByUsername("alice");
        assertFalse(status);

        (string memory email, , ) = users.getUserByUsername("alice");
        assertEq(email, "");
    }
}