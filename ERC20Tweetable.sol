// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ERC20Tweetable {

    constructor () {
        assembly {
            sstore(3, 1000) // Set totalSupply at slot 0
            sstore(4, not(0)) // Set max uint at slot 3

            // give msg.sender total balance
            mstore(0, caller())
            sstore(keccak256(0, 32), 1000)

            // Store Transfer and Approval event topics:
            sstore(1, 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef)
            sstore(0, 0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925)
        }
    }

    fallback () external {
        assembly {
            
            /**
             * Target memory layout:
             * 0x00: [param 0]
             * 0x20: [caller]
             * 0x40: [param 0]
             * 0x60: [param 1]
             * 0x80: [param 2]
             */

            // Copy p0, p1, p2 to mem[0x00:0x60)
            calldatacopy(0, 4, calldatasize())

            // Place caller at 0x20
            mstore(0x20, caller())

            // Copy p0, p1, p2 to mem[0x40:0xA0)
            calldatacopy(0x40, 4, calldatasize())

            // Get first byte of selector
            let func := byte(0, calldataload(0))

            // Hash first param (we need this later)
            let shaP0 := keccak256(0x00, 32)

            /**
             * Check whether func is any of the state-changing methods:
             *
             * transfer(dest, amt)
             * transferFrom(from, dest, amt)
             * approve(dest, amt)
             * 
             * Only check the first byte, since they're all unique
             */

            // 1 if func is transfer; 0 otherwise
            let isTransfer := eq(func, 0xA9)
            // 1 if func is transferFrom; 0 otherwise
            let isTransferFrom := eq(func, 0x23)
            // 1 if func is approve; 0 otherwise
            let isApprove := eq(func, 0x09)

            {
                /**
                 * Handle view functions:
                 * token.balanceOf(owner)
                 * token.allowance(owner, spender)
                 * token.totalSupply()
                 */
            
                // 1 if func is allowance; 0 otherwise
                let isAllowance := eq(func, 0xDD)
                // 1 if func is balanceOf; 0 otherwise
                let isBalanceOf := eq(func, 0x70)
                // 1 if func is totalSupply; 0 otherwise
                let isTotalSupply := eq(func, 0x18)

                /**
                 * Calc readSlot:
                 * allowance: sha(p0, p1)
                 * balanceOf: sha(p0)
                 * totalSupply: 3
                 * other methods: 0
                 */
                let readSlot := or(
                    mul(3, isTotalSupply),
                    or(
                        mul(keccak256(0x40, 64), isAllowance),
                        mul(shaP0, isBalanceOf)
                    )
                )

                // if func is a view function, load slot and return value
                if readSlot {
                    doRet(sload(readSlot))
                }
            }

            // get rid of unneeded vars
            pop(func)

            /**
             * Set transferAmt:
             * transfer: p1
             * transferFrom: p2
             * approve: 0
             */
            let transferAmt := or(
                mul(mload(0x60), isTransfer),
                mul(mload(0x80), isTransferFrom)
            )

            /**
             * Set approvalSlot:
             * transfer: slot_max
             * transferFrom: sha(p0, caller)
             * approve: sha(caller, p0)
             */
            let approvalSlot := or(
                mul(4, isTransfer),
                or(
                    mul(keccak256(0x00, 64), isTransferFrom),
                    mul(keccak256(0x20, 64), isApprove)
                )
            )

            /**
             * Set approvalAmt:
             * transfer: sload(approvalSlot)
             * transferFrom: sload(approvalSlot) - transferAmt
             * approve: p1
             */
            let approvalAmt := or(
                mul(sload(approvalSlot), isTransfer),
                or(
                    mul(sub(sload(approvalSlot), transferAmt), isTransferFrom),
                    mul(mload(0x60), isApprove)
                )
            )

            /**
             * Set fromBalSlot:
             * transfer: sha(caller)
             * transferFrom: sha(p0)
             * approve: 0
             */
            let fromBalSlot := or(
                mul(keccak256(0x20, 32), isTransfer),
                mul(shaP0, isTransferFrom)
            )

            /**
             * Set toBalSlot:
             * transfer: sha(p0)
             * transferFrom: sha(p1)
             * approve: 0
             */
            let toBalSlot := or(
                mul(shaP0, isTransfer),
                mul(keccak256(0x60, 32), isTransferFrom)
            )

            /**
             * Set eventSigSlot:
             * transfer: 1
             * transferFrom: 1
             * approve: 0
             */
            let eventSigSlot := or(isTransfer, isTransferFrom)

            /**
             * Set logAmtPtr:
             * transfer: p1
             * transferFrom: p2
             * approve: p1
             */
            let logAmtPtr := or(
                mul(0x60, or(isTransfer, isApprove)),
                mul(0x80, isTransferFrom)
            )

            /**
             * Set logFromParam:
             * transfer: caller
             * transferFrom: p0
             * approve: caller
             */
            let logFromParam := or(
                mul(caller(), or(isTransfer, isApprove)),
                mul(mload(0x00), isTransferFrom)
            )

            /**
             * Set logToParam:
             * transfer: p0
             * transferFrom: p1
             * approve: p0
             */
            let logToParam := or(
                mul(mload(0x00), or(isTransfer, isApprove)),
                mul(mload(0x60), isTransferFrom)
            )

            // Check balance/allowance requirements
            if or(
                lt(sload(approvalSlot), transferAmt), 
                lt(sload(fromBalSlot), transferAmt)
            ) {
                revert(0, 0)
            }

            sstore(fromBalSlot, sub(sload(fromBalSlot), transferAmt)) // Update from balance
            sstore(toBalSlot, add(sload(toBalSlot), transferAmt)) // Update to balance
            sstore(approvalSlot, approvalAmt) // Update allowance

            // Log Transfer or Approval events
            log3(logAmtPtr, 32, sload(eventSigSlot), logFromParam, logToParam)

            doRet(1)

            function doRet(val) {
                mstore(0, val)
                return(0, 32)
            }
        }
    }
}