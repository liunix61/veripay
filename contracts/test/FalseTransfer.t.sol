// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AgentPayAccount, AgentPayAccountFactory} from "../src/AgentPayAccount.sol";
import {
    FacilitatorSettlement, ReceiptsRegistry
} from "../src/FacilitatorSettlement.sol";

/// @notice PoC for the silent-false-transfer bug class: USDC-style tokens
/// return false instead of reverting on failure. Without the return-value
/// check, executePayment would debit `spent`, log a receipt, and leave the
/// merchant unpaid — a fully "audited" payment that never happened.

contract FalseToken {
    string public constant name = "FalseToken";
    string public constant symbol = "FALSE";
    uint8 public constant decimals = 6;
    mapping(address => uint256) public balanceOf;
    bool public alwaysFalse;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function setAlwaysFalse(bool v) external {
        alwaysFalse = v;
    }

    function transfer(address, uint256) external view returns (bool) {
        return !alwaysFalse;
    }

    function transferFrom(address, address, uint256) external view returns (bool) {
        return !alwaysFalse;
    }
}

contract FalseTransferTest is Test {
    address internal owner = address(0xBEEF);
    address internal merchant = address(0x9999);
    address internal agentKey = address(0x7777);

    FalseToken internal token;
    AgentPayAccount internal account;
    ReceiptsRegistry internal registry;
    FacilitatorSettlement internal settlement;

    function setUp() public {
        token = new FalseToken();
        registry = new ReceiptsRegistry();
        settlement = new FacilitatorSettlement(address(registry));
        registry.registerSettlement(address(settlement), true);

        address[] memory wl = new address[](1);
        wl[0] = merchant;
        vm.prank(owner);
        account = new AgentPayAccount(
            address(token), owner, agentKey,
            AgentPayAccount.AccountPolicy({
                budget: 5e6, perTxMax: 5e6, expiresAt: uint64(block.timestamp + 1 days),
                merchantWhitelist: wl
            })
        );
        vm.prank(account.owner());
        account.setFacilitator(address(settlement), true);
        token.mint(address(account), 1e6);
    }

    function test_executePayment_revertsWhenTokenReturnsFalse() public {
        token.setAlwaysFalse(true);
        vm.prank(address(settlement));
        vm.expectRevert(AgentPayAccount.TransferFailed.selector);
        account.executePayment(merchant, 1e6);

        // state must be fully unwound
        assertEq(account.spent(), 0, "spent must not increase on failed transfer");
        assertEq(registry.receiptCount(), 0, "no receipt for a failed transfer");
    }
}
