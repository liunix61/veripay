// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {FacilitatorSettlement} from "../src/FacilitatorSettlement.sol";

/// @notice Cross-language EIP-712 parity: engine/eip712.py must produce the
/// byte-identical digest as the contract's internal computation.
/// Vectors also asserted in tests/test_eip712.py.
contract Eip712ParityTest is Test {
    bytes32 constant EXPECTED_DOMAIN =
        0x88d3500a2f42686ded12d50e2a94159ee04c57dbfe0c7fb474820060a07dc5e5;
    bytes32 constant EXPECTED_STRUCT =
        0xdbb907e5bf4e70ce8fe5e7e6e2eaae0c34039b5df7c8b9598bba7e41d3c6a3b0;
    bytes32 constant EXPECTED_DIGEST =
        0xfa1a14f2ec5b355b3b5945b37e03b716a997f222a4b008f8d055bb83e53999b8;

    function _authTypehash() internal pure returns (bytes32) {
        return keccak256(
            "PaymentAuth(address account,address merchant,uint256 amount,"
            "uint256 nonce,uint256 deadline,bytes32 resourceHash)"
        );
    }

    function test_domainSeparator_matchesEngine() public pure {
        bytes32 domainTypehash = keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,"
            "address verifyingContract)"
        );
        bytes32 ds = keccak256(abi.encode(
            domainTypehash,
            keccak256("VeriPay"),
            keccak256("1"),
            uint256(421614),
            address(0x5001)
        ));
        assertEq(ds, EXPECTED_DOMAIN, "engine domain separator drifted");
    }

    function test_structHash_and_digest_matchEngine() public pure {
        bytes32 resourceHash =
            hex"cdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcd";
        bytes32 structHash = keccak256(abi.encode(
            _authTypehash(),
            address(0x2001),
            address(0x2002),
            uint256(10000),
            uint256(0),
            uint256(2000000000),
            resourceHash
        ));
        assertEq(structHash, EXPECTED_STRUCT, "engine struct hash drifted");

        bytes32 d = keccak256(abi.encodePacked("\x19\x01", EXPECTED_DOMAIN, structHash));
        assertEq(d, EXPECTED_DIGEST, "engine digest drifted");
    }

    function test_contractAuthTypehash_matchesEngineLiteral() public {
        // deploy a real settlement and compare its public constant against
        // the typehash the engine computes from the same string literal
        FacilitatorSettlement s = new FacilitatorSettlement(address(0xdead));
        assertEq(s.AUTH_TYPEHASH(), _authTypehash(), "AUTH_TYPEHASH literal drifted");
        assertEq(
            s.PAYMENT_AUTH_TYPEHASH_STR(),
            "PaymentAuth(address account,address merchant,uint256 amount,uint256 nonce,uint256 deadline,bytes32 resourceHash)",
            "typehash source string drifted"
        );
    }
}
