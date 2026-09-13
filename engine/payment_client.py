"""x402 payment client: sign a PaymentAuth, hand it to a facilitator.

The facilitator is relay-agnostic by design (matches the contract): anyone
can submit the signed payload, only the session key can authorize it.
"""

from __future__ import annotations

import time
from dataclasses import dataclass

from eth_account import Account

from .eip712 import PaymentAuth, digest


@dataclass
class PaymentRequest:
    merchant: str
    amount: int
    resource_hash: str
    account_address: str        # the AgentPayAccount paying
    settlement_address: str     # FacilitatorSettlement (verifyingContract)
    chain_id: int


class PaymentClient:
    """Signs x402 payment authorizations with the agent's session key."""

    def __init__(self, session_key: str):
        """session_key: hex private key of the agent session key."""
        if not session_key:
            raise ValueError("session key required")
        self._acct = Account.from_key(session_key)

    @property
    def address(self) -> str:
        return self._acct.address

    def sign(self, req: PaymentRequest, nonce: int,
             ttl_sec: int = 300) -> tuple[PaymentAuth, str]:
        """Returns (auth, signature_hex). Signature is 65-byte r||s||v,
        exactly what FacilitatorSettlement.settle expects."""
        auth = PaymentAuth(
            account=req.account_address,
            merchant=req.merchant,
            amount=req.amount,
            nonce=nonce,
            deadline=int(time.time()) + ttl_sec,
            resource_hash=req.resource_hash,
        )
        d = digest(auth, req.chain_id, req.settlement_address)
        sig = self._acct.unsafe_sign_hash(d)
        return auth, "0x" + sig.signature.hex()

    @staticmethod
    def recover(auth: PaymentAuth, signature: str,
                chain_id: int, settlement_address: str) -> str:
        """Who signed? Mirrors SettlementLib.recover for local pre-flight."""
        d = digest(auth, chain_id, settlement_address)
        return Account._recover_hash(  # pyright: ignore[reportPrivateUsage]
            d, signature=bytes.fromhex(signature.removeprefix("0x"))
        )
