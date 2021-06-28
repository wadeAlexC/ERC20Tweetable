// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Deployer {
    
    // Contains bytecode from asm_bytecode.txt
    bytes constant code = hex"3660046000373360205236600460403760003560001a602060002060a98214602383146009841460dd851460708614601887148187028360406040200217816003021780156100535761005281546100ff565b5b5050505084508160805102836060510217816040602020028360406000200217846004021782606051028483835403021785825402178487028660206020200217856020606020028789021786881787608002878a17606002178860005102888b173302178960605102898c176000510217888654108989541017156100d95760006000fd5b88865403865588855401855586885580828554602086a36100fa60016100ff565b61010c565b8060005260206000f3";
    
    constructor () public {
        bytes memory ret = code;
        assembly {
            sstore(3, 1000) // Set totalSupply at slot 0
            sstore(4, not(0)) // Set max uint at slot 3

            // give msg.sender total balance
            mstore(0, caller())
            sstore(keccak256(0, 32), 1000)

            // Store Transfer and Approval event topics:
            sstore(1, 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef)
            sstore(0, 0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925)
            
            return(add(32, ret), mload(ret))
        }
    }
}