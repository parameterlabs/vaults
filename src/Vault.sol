// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Ownable} from "solady/auth/Ownable.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

contract Vault is Ownable {
    mapping(bytes4 => address) public routes;

    constructor(address owner) {
        _initializeOwner(owner);
    }

    // Batch register function selectors against target contracts
    function addRoutes(
        bytes4[] memory functionSelectors,
        address[] memory targetContracts
    ) public onlyOwner {
        require(
            functionSelectors.length == targetContracts.length,
            "Array lengths must match"
        );

        for (uint i = 0; i < functionSelectors.length; i++) {
            // Add authorization checks as needed
            routes[functionSelectors[i]] = targetContracts[i];
        }
    }

    // Batch remove routes
    function removeRoutes(bytes4[] memory functionSelectors) public onlyOwner {
        for (uint i = 0; i < functionSelectors.length; i++) {
            // Add authorization checks as needed
            delete routes[functionSelectors[i]];
        }
    }

    function withdrawERC20(
        address token,
        address to,
        uint256 amount
    ) public onlyOwner {
        SafeTransferLib.safeTransfer(token, to, amount);
    }

    function withdrawETH(address to, uint256 amount) public onlyOwner {
        SafeTransferLib.safeTransferETH(to, amount);
    }

    fallback() external payable {
        bytes4 functionSelector = bytes4(msg.data[:4]);
        address target = routes[functionSelector];
        if (target != address(0) && msg.sender == owner()) {
            (bool success, ) = target.delegatecall(msg.data);
            require(success, "Delegatecall failed");
        }
    }

    receive() external payable {}

    /// @dev Modifier for the fallback function to handle token callbacks.
    modifier receiverFallback() virtual {
        _;
        /// @solidity memory-safe-assembly
        assembly {
            let s := shr(224, calldataload(0))
            // 0x150b7a02: `onERC721Received(address,address,uint256,bytes)`.
            // 0xf23a6e61: `onERC1155Received(address,address,uint256,uint256,bytes)`.
            // 0xbc197c81: `onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)`.
            if or(eq(s, 0x150b7a02), or(eq(s, 0xf23a6e61), eq(s, 0xbc197c81))) {
                mstore(0x20, s) // Store `msg.sig`.
                return(0x3c, 0x20) // Return `msg.sig`.
            }
        }
    }
}
