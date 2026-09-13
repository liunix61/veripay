// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {AgentPayAccountFactory} from "../src/AgentPayAccount.sol";
import {FacilitatorSettlement, ReceiptsRegistry} from "../src/FacilitatorSettlement.sol";

/// @notice Deploys the VeriPay contract set.
/// Usage:
///   forge script script/Deploy.s.sol --rpc-url $RPC_URL --broadcast --private-key $PK
/// Env:
///   USDC_ADDRESS — native USDC (Arbitrum One: 0xaf88d065e77c8cC2239327C5EDb3A432268e5831)
contract Deploy is Script {
    function run() external {
        uint256 pk = vm.envUint("DEPLOYER_PK");
        address usdc = vm.envAddress("USDC_ADDRESS");

        vm.startBroadcast(pk);

        ReceiptsRegistry registry = new ReceiptsRegistry();
        FacilitatorSettlement settlement = new FacilitatorSettlement(address(registry));
        AgentPayAccountFactory factory = new AgentPayAccountFactory(usdc);

        // wire: settlement is a registered receipt writer
        registry.registerSettlement(address(settlement), true);

        vm.stopBroadcast();

        console.log("ReceiptsRegistry:", address(registry));
        console.log("FacilitatorSettlement:", address(settlement));
        console.log("AgentPayAccountFactory:", address(factory));
    }
}
