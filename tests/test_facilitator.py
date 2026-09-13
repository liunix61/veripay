"""Facilitator service tests — mock mode + calldata encoding round-trip."""

import os
import sys
import time

import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "facilitator"))

from eth_abi.abi import decode as abi_decode

from facilitator import (
    Facilitator, auth_tuple, settle_calldata, verify_calldata,
    SETTLE_SELECTOR, VERIFY_SELECTOR,
)

AUTH = {
    "account": "0x" + "11" * 20,
    "merchant": "0x" + "22" * 20,
    "amount": 10_000,          # $0.01 USDC (6dp)
    "nonce": 0,
    "deadline": int(time.time()) + 300,
    "resourceHash": "0x" + "ab" * 32,
}


def _mock_fac() -> Facilitator:
    return Facilitator(rpc="", settlement="0x" + "00" * 20, chain_id=421614, relayer_key="")


def test_mock_verify_passes_fresh_auth():
    assert _mock_fac().verify(AUTH) == {"ok": True, "reason": ""}


def test_mock_verify_rejects_expired():
    expired = {**AUTH, "deadline": 1}
    assert _mock_fac().verify(expired) == {"ok": False, "reason": "EXPIRED"}


def test_mock_verify_rejects_zero_amount():
    assert _mock_fac().verify({**AUTH, "amount": 0})["ok"] is False


def test_mock_settle_refuses_invalid_auth():
    res = _mock_fac().settle({**AUTH, "deadline": 1}, "0x" + "00" * 65)
    assert res["ok"] is False and res["reason"] == "EXPIRED"


def test_mock_settle_returns_deterministic_txhash():
    a = _mock_fac().settle(AUTH, "0x" + "11" * 65)
    b = _mock_fac().settle(AUTH, "0x" + "11" * 65)
    assert a["ok"] and a["txHash"].startswith("0x") and len(a["txHash"]) == 66
    assert a["txHash"] == b["txHash"]


def test_settle_calldata_roundtrip():
    sig = bytes.fromhex("22" * 65)
    cd = settle_calldata(auth_tuple(AUTH), sig)
    assert cd[:4] == SETTLE_SELECTOR
    t, s = abi_decode(["(address,address,uint256,uint256,uint256,bytes32)", "bytes"], cd[4:])
    assert t[0] == AUTH["account"].lower() or t[0] == AUTH["account"]
    assert t[2] == AUTH["amount"]
    assert s == sig


def test_verify_calldata_roundtrip():
    cd = verify_calldata(auth_tuple(AUTH))
    assert cd[:4] == VERIFY_SELECTOR
    (t,) = abi_decode(["(address,address,uint256,uint256,uint256,bytes32)"], cd[4:])
    assert t[3] == AUTH["nonce"] and t[4] == AUTH["deadline"]


def test_health_shape():
    h = _mock_fac().health()
    assert h["ok"] and h["mode"] == "mock" and h["chainId"] == 421614
