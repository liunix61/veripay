"""VeriPay engine: x402 payment client.

Builds and signs PaymentAuth payloads whose EIP-712 digest is byte-identical
to FacilitatorSettlement.sol's internal digest (proven by Eip712Parity.t.sol /
tests/test_eip712.py), then relays them to a facilitator.
"""

__version__ = "0.1.0"
