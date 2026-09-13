"""EIP-712 parity — same vectors asserted in Eip712Parity.t.sol."""

import os
import sys

import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from engine.eip712 import PaymentAuth, digest, domain_separator, AUTH_TYPEHASH
from engine.payment_client import PaymentClient, PaymentRequest

SETTLEMENT = "0x0000000000000000000000000000000000005001"
CHAIN = 421614

AUTH = PaymentAuth(
    account="0x0000000000000000000000000000000000002001",
    merchant="0x0000000000000000000000000000000000002002",
    amount=10_000,
    nonce=0,
    deadline=2_000_000_000,
    resource_hash="0x" + "cd" * 32,
)

EXPECTED_DOMAIN = "0x88d3500a2f42686ded12d50e2a94159ee04c57dbfe0c7fb474820060a07dc5e5"
EXPECTED_STRUCT = "0xdbb907e5bf4e70ce8fe5e7e6e2eaae0c34039b5df7c8b9598bba7e41d3c6a3b0"
EXPECTED_DIGEST = "0xfa1a14f2ec5b355b3b5945b37e03b716a997f222a4b008f8d055bb83e53999b8"


def test_domain_separator_matches_solidity():
    assert "0x" + domain_separator(CHAIN, SETTLEMENT).hex() == EXPECTED_DOMAIN


def test_struct_hash_matches_solidity():
    assert "0x" + AUTH.struct_hash().hex() == EXPECTED_STRUCT


def test_digest_matches_solidity():
    assert "0x" + digest(AUTH, CHAIN, SETTLEMENT).hex() == EXPECTED_DIGEST


def test_auth_typehash_matches_contract_literal():
    # must equal the string literal inside FacilitatorSettlement.sol
    expected = (
        "0x"
        + __import__("eth_hash.auto", fromlist=["keccak"]).keccak(
            b"PaymentAuth(address account,address merchant,uint256 amount,"
            b"uint256 nonce,uint256 deadline,bytes32 resourceHash)"
        ).hex()
    )
    assert "0x" + AUTH_TYPEHASH.hex() == expected


# ── client round trip ──────────────────────────────

TEST_KEY = "0x" + "42" * 32


def test_client_sign_and_recover_roundtrip():
    client = PaymentClient(TEST_KEY)
    req = PaymentRequest(
        merchant=AUTH.merchant,
        amount=AUTH.amount,
        resource_hash=AUTH.resource_hash,
        account_address=AUTH.account,
        settlement_address=SETTLEMENT,
        chain_id=CHAIN,
    )
    auth, sig = client.sign(req, nonce=7, ttl_sec=600)
    recovered = PaymentClient.recover(auth, sig, CHAIN, SETTLEMENT)
    assert recovered.lower() == client.address.lower()


def test_client_requires_key():
    with pytest.raises(ValueError, match="session key required"):
        PaymentClient("")


def test_recovered_signer_not_mallory():
    client = PaymentClient(TEST_KEY)
    req = PaymentRequest(
        merchant=AUTH.merchant, amount=AUTH.amount,
        resource_hash=AUTH.resource_hash, account_address=AUTH.account,
        settlement_address=SETTLEMENT, chain_id=CHAIN,
    )
    auth, sig = client.sign(req, nonce=1)
    other = PaymentClient("0x" + "43" * 32)
    assert PaymentClient.recover(auth, sig, CHAIN, SETTLEMENT).lower() != other.address.lower()
