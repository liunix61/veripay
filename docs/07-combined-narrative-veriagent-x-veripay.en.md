# 07 — Combined Narrative: VeriAgent × VeriPay (Full-Stack AI Agent Financial Primitives)

> Arbitrum Open House Singapore Buildathon 2026 · Promising Products (AI agents + new financial primitives)

## One line

**VeriAgent audits every investment decision an AI agent makes; VeriPay audits every payment it sends — both ends of an AI agent's money flow are verifiably on-chain.**

## Dual-project positioning

| | VeriAgent (Robinhood Chain track) | VeriPay (Arbitrum One track) |
|---|---|---|
| Problem | Why trust an agent's trading decisions? | Why won't an agent's payment keys drain the account? |
| Core primitive | Credential-before-trade (four hashes + two-phase record→bindTx) | Limited smart account (EIP-712 auth + on-chain receipts) |
| Asset direction | bStocks/RWA tokenized-asset management (SEC TSV alignment) | USDC x402 machine-payment settlement |
| Audit form | Decision evidence: action/reason/dataSource/model four hashes | Payment evidence: merchant/amount/resource-hash receipts |
| Constraint engine | Vault policy: whitelist / position cap / daily-loss breaker / cooldown / frequency | Account policy: budget / whitelist / per-tx cap / expiry / revoke |

Both projects share one design philosophy: **constraints live in the contract, evidence lives on-chain, ordering is independently verifiable**.

## Combined scenario: an agent's full financial lifecycle

```
┌─ Decision side (VeriAgent) ──────────────────────────┐
│  market snapshot → Jev/NanoJev decision → four-hash │
│  credential on-chain → trade bStocks within vault   │
│  policy → bindTx (HALTED hard-reject; dividends      │
│  audited via dividend_ack + notifyDividend)          │
└──────────────────────┬───────────────────────────────┘
                       │ agent needs to PAY: market API,
                       │ data feeds, trading fees
┌─ Payment side (VeriPay) ─────────────────────────────┐
│  x402 request → EIP-712 session-key authorization    │
│  → FacilitatorSettlement verify/replay-guard          │
│  → AgentPayAccount hard limits (budget/whitelist/    │
│  per-tx cap) → USDC settle + ReceiptsRegistry        │
└──────────────────────────────────────────────────────┘
```

Every investment decision has a decision credential; every data purchase has a
payment receipt — **the agent's complete money in/out ledger is auditable**.

## Dual-track decision-model access

The decision-model layer is not vendor-locked:

- **Jev** (TypeSafe System One): commercial API, typed decisions + calibrated confidence
- **NanoJev** (open source, liunix61/NanoJev fork): Qwen3-0.6B + decision heads,
  self-hosted `POST /api/evaluate`, zero API cost

Both emit the same `JevDecision` contract (action + confidence) and run the same
VeriAgent credential pipeline; `model_id`/`modelHash` distinguish lineage on-chain.
**Open decision models make audits reproducible** — anyone can load the same weights
locally and replay an audited decision (closed APIs cannot).

Pairing: VeriPay's limited account budgets the agent's commercial decision-API
spend (e.g. Jev API capped at $5/month — once spent, physically impossible to
overspend on-chain).

## Judging criteria mapping

| Buildathon criterion | Combined-project answer |
|---|---|
| Contract quality | 114 forge tests across both projects (84+30) + cross-language hash/EIP-712 parity (same vectors asserted in pytest AND forge) |
| PMF | RWA tokenization (SEC 9/17 exemption) + AI-agent payments (x402) are both 2026-definite tracks; the Jev ecosystem hit 1.1k stars in 3 days — agent decision infrastructure demand is exploding |
| Innovation | "Decision credential" and "limited payment account" are both primitives the industry lacks; dual-track decision-model auditing (with reproducible open-source lineage) is a first |
| Real problem | Agent asset-management trust deficit + agent payment key-drain fear — real operator concerns physically eliminated by contracts |

## Repos & tests

- VeriAgent: `liunix61/veriagent` — 84 forge + 59 pytest (RWA compliance layer + Jev/NanoJev audit layer)
- VeriPay: `liunix61/veripay` — 30 forge + 15 pytest (EIP-712 settlement + FalseTransfer fix)
