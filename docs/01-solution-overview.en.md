# VeriPay Solution Overview

> Arbitrum Open House Singapore Buildathon — Project #2
> Target: the "Arbitrum chain" reserved slot in Overall top 3 (deployed on Arbitrum One mainnet)
> Differentiated from Project #1 VeriAgent (Robinhood Chain); shares engine code
> Created: 2026-09-13

---

## 1. One-line Positioning

**VeriPay = native payment rails for AI agents**: instead of handing agents the user's credit card or API keys, agents pay per call through "limit-enforced smart accounts + the x402 protocol", with an on-chain receipt for every machine purchase.

## 2. The Real Problem

**Problem**: agentic commerce is exploding in 2026 but the payment layer is missing:

1. **Excessive permissions**: an agent that needs to pay must hold full user payment credentials — a leak means unlimited loss
2. **No ledger for machine spending**: what the agent bought, from whom, for how much — users can't audit after the fact
3. **Micropayments don't work**: legacy rails have minimum fees; $0.01 API calls can't settle on cards

**VeriPay's answer**:
- **Limit-enforced accounts**: one smart account per agent; budget / merchant whitelist / TTL hard-enforced by contract → leak damage is capped
- **x402-native**: HTTP 402 machine payments, USDC settlement, $0.001-level viable on L2
- **On-chain receipts**: every settlement writes to ReceiptsRegistry (merchant/amount/resource hash) → machine spending is auditable

## 3. Differentiation from VeriAgent (two-project strategy)

| Dimension | VeriAgent (#1) | VeriPay (#2) |
|-----------|---------------|--------------|
| Narrative | AI agent asset-management primitive | Agent payment / wallet infrastructure |
| Chain | Robinhood Chain (reserved slot A) | **Arbitrum One mainnet** (reserved slot B) |
| Core contracts | Vault + DecisionRecorder | Limit account + settlement + receipts |
| Users | Investors | Agent developers / merchants |
| Shared | engine, x402 client, frontend, Explorer pattern | same |

Complementary, not duplicative: VeriAgent's PaymentRouter calls VeriPay contracts directly — demos cross-reference to show an ecosystem.

## 4. Product Shape

```
Developer spins up agent → deploys AgentPayAccount ($50 budget / whitelist / 30-day TTL)
                    │
Agent calls a paid API ←── HTTP 402 + price
Agent signs payment with session key → Facilitator verifies + settles (USDC on Arbitrum One)
                    │
ReceiptsRegistry logs receipt → user panel: live spending stream + budget remaining
Over budget / off-whitelist / expired → contract rejects; the agent simply cannot pay
```

Three components:
1. **AgentPayAccount factory**: one-click limit-enforced payment accounts for agents (ERC-4337-style, deliberately minimal)
2. **x402 Facilitator**: open-source settlement service (self-hostable) — verify signature → settle on-chain → release data
3. **Spending console**: live spend stream, budget controls, receipt verification

## 5. Tracks & Winning Strategy

| Target | Path |
|--------|------|
| **Overall top-3 "Arbitrum chain" reserved slot** | real Arbitrum One mainnet deployment + real USDC micro-settlement demo |
| Promising Products (fallback if VeriAgent takes Overall) | agentic commerce is explicitly on the official direction list |
| Grants | x402 ecosystem infrastructure narrative (protocol co-pushed by AWS/Arbitrum/Coinbase) |

Judging criteria: contract quality (Foundry suite + attack PoCs) / PMF (x402 is a 2026 certainty; AWS AgentCore & CMC already integrated) / innovation (limit smart account + receipt registry is a new combination) / real problem (agent payment trust deficit).

## 6. Reused Assets

| Source | Use |
|--------|-----|
| VeriAgent PaymentRouter design | promoted to a standalone settlement contract |
| VeriAgent x402_client.py | engine-side payment client reused as-is |
| HOODflow MCP pattern | data-source integration |
| VeriAgent Explorer frontend | receipt verification UI, same shape |

## 7. Three-Week Milestones (parallel with VeriAgent, shared code)

| Week | Deliverables |
|------|--------------|
| W1 (9/14–9/20) | Contracts: AgentPayAccount (factory + limits) + ReceiptsRegistry + Foundry tests; deploy to Arbitrum Sepolia |
| W2 (9/21–9/27) | Facilitator service (open-source, self-hostable) + engine x402 loop (mock merchant first); **deploy to Arbitrum One mainnet** (real USDC) |
| W3 (9/28–10/4) | Spending console + end-to-end demo (real mainnet $0.01-level payments) + submission |

**Demo script**:
1. Create agent payment account: $5 budget, CMC-only whitelist, 48h TTL
2. Agent calls CMC data API → 402 → pays $0.01 USDC (real Arbitrum One tx)
3. Console shows receipt; Explorer verifies it on-chain
4. Attempt an off-whitelist merchant → contract rejects

## 8. Social Extension: Agent Signal Subscriptions + Rev-Share (W3 stretch)

**Positioning**: a "lite" take on FOMO social trading — no copy-trading fund pool; a **signal subscription economy**:

```
Top strategy agent (e.g. a VeriAgent agentId) ──registers as a VeriPay merchant──→ publishes signal stream
Follower agents/users ──subscribe via VeriPay ($1/week)──→ receive trade signals (side/size/rationale)
Subscription fee auto-split: 70% agent creator / 20% platform treasury / 10% referrer
```

- **FOMO mechanics**: live agent PnL leaderboard (sourced from on-chain DecisionRecords — ungameable) + live subscriber counts + limited subscription windows
- **Contract delta**: only a RevenueSplitter + AgentProfile extension; ReceiptsRegistry reused as subscription receipts
- **Integrity pitch**: leaderboard PnL comes entirely from on-chain decision credentials — "FOMO without false advertising", closing the loop with VeriAgent's verifiability narrative
- **Copy-execution layer** (follower funds mirroring trades) is a post-event roadmap item — custody/compliance concerns, out of competition scope

## 9. V2 Roadmap: FOMO Copy-Trading Social Wallet (post-event; the "use of funds" answer)

**Judgment**: no technical moat stands in the way of a copy-trading wallet (vault constraints + mirror execution + rev-share all have ready building blocks); it's skipped during the event because custody-grade security engineering is heavy — a rough version is worse than none. As a V2 roadmap it is the best possible answer to the Promising Products "Requesting funding" criterion.

### V2 Core Additions (vs. the competition build)

| Component | Design | Effort |
|-----------|--------|--------|
| FollowerVault | users deposit → mirror a chosen strategy agent, replicating its on-chain trades pro-rata; entry/exit via queues to prevent front-running | ~2 weeks |
| Mirror execution engine | watch leader DecisionRecorder events → batch pro-rata fills → slippage guard (reject beyond threshold) | ~1 week |
| High-water-mark fees | 10-20% performance fee (charged only on new profits above HWM); RevenueSplitter reused | ~3 days |
| Fund security engineering | timelock + multisig governance + exit queue + independent audit + formal verification of critical paths | ~3 weeks |
| Compliance architecture | staged jurisdiction review (rev-share = advisory gray zone); testnet + capped beta first | ongoing |

### Post-Event Milestones

| Stage | Content |
|-------|---------|
| M1 (+1 month) | FollowerVault + mirror engine on testnet + audit prep |
| M2 (+2 months) | audit passed → capped Arbitrum One beta (≤$500 per vault) |
| M3 (+3 months) | compliance opinion + live performance fees + Base/multi-chain expansion |

### Pitch Line

"The competition build deliberately avoids custody — limit-enforced payments and zero-custody subscriptions are the boundary we can audit and ship; the V2 copy-trading wallet's custody security engineering (audit/multisig/exit queues/high-water-mark accounting) is exactly what this investment funds."

## 10. Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Mainnet real-funds complexity | tiny amounts ($5 budget); full flow proven on testnet first |
| x402 merchant ecosystem is young | ship a mock merchant + real CMC b402 test; spec-aligned interfaces |
| Time conflict with VeriAgent | shared monorepo; W1 contracts first, then parallel; separate directories |
