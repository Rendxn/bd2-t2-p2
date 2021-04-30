pragma solidity ^0.8.4;

// SPDX-License-Identifier: MIT

import "./_Owned.sol";

contract Destructible is Owned {
    
    constructor() {
        destroyCount = 0;
    }
    
    uint8 destroyCount;
    event Destroyed(address _owner, uint8 tries);
    
    function destroy() public onlyOwner {
        destroyCount += 1;
        
        if(destroyCount >= 3) {
            emit Destroyed(owner, destroyCount);
            selfdestruct(owner);
        }
    }
}
