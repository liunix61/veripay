# VeriPay Core Flows

> Created: 2026-09-13 | Related: 01-solution-overview / 02-system-architecture / 03-technical-framework

---

## Flow 1: Creating an Agent Payment Account

```
Developer                     AgentPayAccount factory
  │ 1. define policy: $5 budget / whitelist[CMC] / ≤$0.5 per tx / 48h TTL
  │ 2. createAccount(policy) ──→ account address + agent session key bound
  │ 3. topUp($5 USDC) ────────→ budget in place
```

- One account per agent; accounts fully isolated
- Policy changes require owner + a fresh account (simple model — no backdoors for the agent)

## Flow 2: x402 Paid Call (core loop)

```
Agent engine          Merchant API         Facilitator            Contracts
────────────          ────────────         ───────────            ─────────
GET /signal?NVDA
              ←──402 {price:$0.01, settlement:0x…, dataHash}
sign PaymentAuth (EIP-712)
POST /settle(auth, sig) ─────────────────→ verify sig + eth_call limits
                                           settle() ────────────→ USDC transfer
                                                                   + receipt logged
              ←──200 {data, receiptId} ←── return receiptId
data + receiptId → engine log & console display
```

**Ordering guarantee**: settle before delivery (merchant releases data after seeing the on-chain event); if a merchant fails to deliver, the resourceHash receipt is the evidence.

## Flow 3: Limit Rejection Scenarios

| Scenario | Check point | Reason returned | Agent behavior |
|----------|-------------|----------------|----------------|
| Merchant not whitelisted | checkLimits #3 | NOT_WHITELISTED | skip the call |
| Per-tx cap exceeded | checkLimits #4 | TX_TOO_LARGE | split or degrade |
| Budget exhausted | checkLimits #5 | BUDGET_EXHAUSTED | notify user or stop |
| TTL expired | checkLimits #1 | EXPIRED | stop paid calls |
| Account revoked | checkLimits #2 | REVOKED | stop immediately |

All rejections are knowable off-chain at the eth_call stage — the facilitator's /verify pre-checks, wasting no gas.

## Flow 4: User Audit & Control

```
Spending console:
- Live stream: time / merchant / amount / resource description (from receipt events)
- Budget remaining: budget - spent (live on-chain read)
- One-click revoke: account frozen instantly
- Receipt verification: receiptId → verify() → self-attesting on-chain
```

## Flow 5: Merchant Integration

```
1. Register: deploy/register merchant address
2. Retrofit API: middleware checks 402 (one-line paywall(verify_url, price))
3. Get paid: watch Settlement.settle events → deliver
4. Reconcile: query ReceiptsRegistry history
```

Merchants never need to trust the facilitator — the on-chain event is proof of payment.

## Flow 6: Competition Demo Script (2.5-min video)

```
00:00  Hook: "An agent needs to pay — would you give it your credit card?"
00:20  Create account: $5 budget / whitelist / TTL, show contract on Arbitrum One mainnet
00:50  Agent pays $0.01 USDC for real data → mainnet tx hash
01:20  Console stream + on-chain receipt verification
01:50  Violation demos: off-whitelist merchant rejected / overspend rejected
02:20  Summary: native rails for agent payments
```

## Exception Matrix

| Exception | Handling |
|-----------|----------|
| Settled but merchant didn't deliver | receipt exists; resourceHash proves it; user can appeal/revoke |
| Facilitator outage | merchants can self-host; credentials stay valid on-chain; swap service |
| Agent key leak | revoke + loss ≤ budget balance |
| Mainnet gas spikes | L2 costs are naturally tiny; 2x buffer reserved |
