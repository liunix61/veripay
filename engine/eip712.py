"""EIP-712 digest parity with FacilitatorSettlement.sol.

Contract side (FacilitatorSettlement.settle):
    structHash = keccak256(abi.encode(AUTH_TYPEHASH, account, merchant,
                                      amount, nonce, deadline, resourceHash))
    digest     = keccak256("\\x19\\x01" || DOMAIN_SEPARATOR || structHash)

All fields are static (address/uint256/bytes32) so the encoding is a plain
32-byte-word concatenation — no dynamic offsets. Same vector asserted on
both sides in Eip712Parity.t.sol and tests/test_eip712.py.
"""

from __future__ import annotations

from dataclasses import dataclass
from eth_hash.auto import keccak

WORD = 32

AUTH_TYPEHASH_STR = (
    "PaymentAuth(address account,address merchant,uint256 amount,"
    "uint256 nonce,uint256 deadline,bytes32 resourceHash)"
)
EIP712_DOMAIN_TYPEHASH_STR = (
    "EIP712Domain(string name,string version,uint256 chainId,"
    "address verifyingContract)"
)
NAME = "VeriPay"
VERSION = "1"

AUTH_TYPEHASH = keccak(AUTH_TYPEHASH_STR.encode())
EIP712_DOMAIN_TYPEHASH = keccak(EIP712_DOMAIN_TYPEHASH_STR.encode())


def _word_int(v: int) -> bytes:
    return v.to_bytes(WORD, "big")


def _word_addr(addr: str) -> bytes:
    a = addr.lower().removeprefix("0x")
    if len(a) != 40:
        raise ValueError(f"bad address: {addr}")
    return bytes(12) + bytes.fromhex(a)


def _word_b32(h: str) -> bytes:
    b = bytes.fromhex(h.lower().removeprefix("0x"))
    if len(b) != 32:
        raise ValueError("bytes32 required")
    return b


@dataclass(frozen=True)
class PaymentAuth:
    account: str      # smart-account address (payer)
    merchant: str
    amount: int
    nonce: int
    deadline: int
    resource_hash: str  # 0x + 64 hex

    def struct_hash(self) -> bytes:
        return keccak(
            AUTH_TYPEHASH
            + _word_addr(self.account)
            + _word_addr(self.merchant)
            + _word_int(self.amount)
            + _word_int(self.nonce)
            + _word_int(self.deadline)
            + _word_b32(self.resource_hash)
        )


def domain_separator(chain_id: int, verifying_contract: str) -> bytes:
    return keccak(
        EIP712_DOMAIN_TYPEHASH
        + keccak(NAME.encode())
        + keccak(VERSION.encode())
        + _word_int(chain_id)
        + _word_addr(verifying_contract)
    )


def digest(auth: PaymentAuth, chain_id: int, verifying_contract: str) -> bytes:
    """The exact value the session key signs."""
    return keccak(
        b"\x19\x01"
        + domain_separator(chain_id, verifying_contract)
        + auth.struct_hash()
    )
