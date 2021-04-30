pragma solidity ^0.8.4;

// SPDX-License-Identifier: MIT

contract Owned {
    constructor() {
        owner = payable(msg.sender);
    }

    address payable owner;

    /**
     * Only the defined owner can call the _ function
     * that is inserted.
     */
    modifier onlyOwner {
        require(msg.sender == owner, unicode"Solo el dueño puede hacer esto.");
        _;
    }
}
