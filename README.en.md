# VeriPay — Limit-Enforced Payment Rails for AI Agents (x402 Settlement)

> Arbitrum Open House Singapore Buildathon 2026 · Arbitrum One

**In one line**: every AI agent gets an on-chain limit-enforced smart account —
budget, whitelist, per-tx cap, expiry all contract-enforced; every payment
carries an EIP-712 authorization signature and an on-chain receipt.

## The problem, stated plainly

When agents pay autonomously for APIs/data/compute (the x402 pattern), the
operator's nightmare is: leaked key = unlimited drain. VeriPay moves the
control from "post-hoc alerting" to "physically impossible on-chain":

| Rule | Contract-enforced |
|---|---|
| Budget cap (e.g. $5/month) | ✅ hard stop, on-chain balance conservation |
| Merchant whitelist | ✅ non-whitelisted addresses revert |
| Per-transaction cap | ✅ prevents one-shot drains |
| Expiry | ✅ expired account is dead |
| Instant revoke | ✅ owner kills it in one tx |
| Session-key rotation | ✅ leaked key dies immediately |

## Architecture

```
Agent engine                  On-chain
┌──────────────┐   EIP-712   ┌────────────────────────┐
│ PaymentClient │──signs────▶│ FacilitatorSettlement  │
│ (session key) │            │  sig/nonce/replay guard│
└──────────────┘             │        ↓               │
                             │ AgentPayAccount        │
 Anyone may relay            │  4 hard limits + revoke│
 (relay-agnostic)            │        ↓ USDC transfer │
                             │ ReceiptsRegistry       │
                             │  (on-chain receipts)   │
└─────────────────────────────────────────────────────┘
```

**Cross-language EIP-712 parity**: `engine/eip712.py` produces digests
byte-identical to the contract's internal computation; one fixed vector is
asserted in BOTH pytest and forge test (`Eip712Parity.t.sol`).

## Quickstart

```bash
cd contracts && forge test     # 29 tests (incl. 3 parity)
cd .. && python3 -m pytest tests/ -q   # 7 tests
```

## V2 roadmap: the copy-trading wallet (FOMO-style social trading)

This build ships the signal-subscription layer; **FollowerVault mirror
copy-trading** (follower funds locked in a limit-enforced vault replicating a
target agent's verified trade stream) is the V2 roadmap — the answer to the
Promising Products "Requesting funding" question. See `docs/01-总体方案.md`
§8/§9.

## Docs

`docs/` — bilingual (ZH/EN) four-piece set: master plan / architecture /
tech stack / core flows.

## License

MIT
