# VeriPay System Architecture

> Created: 2026-09-13 | Related: 01-solution-overview / 03-technical-framework / 04-core-flows

---

## 1. Architecture Overview

```
┌────────────────────────────────────────────────────────────┐
│          Spending Console (Nuxt4, shared frontend)          │
│   Account mgmt      Live spend stream      Receipt verify   │
└────────┬───────────────────────┬───────────────────────────┘
         │ viem                  │
┌────────▼───────────────────────▼───────────────────────────┐
│           Contracts (Solidity, Arbitrum One mainnet)         │
│  ┌──────────────────┐  ┌───────────────┐  ┌─────────────┐ │
│  │ AgentPayAccount  │  │ Facilitator   │  │ Receipts    │ │
│  │ (factory+limits) │→│ Settlement    │→│ Registry    │ │
│  │ budget/whitelist │  │ (USDC settle) │  │ (receipt    │ │
│  │ /TTL             │  │               │  │  hashes)    │ │
│  └──────────────────┘  └───────────────┘  └─────────────┘ │
└────────┬───────────────────────────────────────────────────┘
         │                        │
┌────────▼──────────┐   ┌────────▼─────────────────────────┐
│ Agent engine       │   │ x402 Facilitator service          │
│ (Python, reuses    │←→│ (open-source, self-hostable:      │
│  x402_client)      │   │  verify / settle / release)       │
└────────┬──────────┘   └────────┬─────────────────────────┘
         │ HTTP 402               │ on-chain settlement
┌────────▼────────────────────────▼────────────────────────┐
│  Paid merchants: CMC data / research agents / oracles /   │
│  any API                                                  │
└───────────────────────────────────────────────────────────┘
```

## 2. Contract Layer

### 2.1 AgentPayAccount (limit-enforced smart account, core)

```
AccountPolicy {
    budget (uint256)           // total budget (USDC, 6 decimals)
    spent (uint256)            // consumed so far
    merchantWhitelist (mapping(address => bool))
    perTxMax (uint256)         // per-payment cap
    expiresAt (uint64)         // TTL
    paused (bool)
}

Key functions:
- createAccount(policy)        // factory; one account per agent
- authorizePayment(merchant, amount, nonce, sig)  // agent session-key signature
- checkLimits(merchant, amount) → (bool, reason)  // budget/whitelist/per-tx/TTL
- topUp(amount) / revoke()     // owner fund / freeze
```

- The agent never custodies funds — it can only "request authorized payment"
- Four limits checked in-contract: budget remaining, merchant whitelist, per-tx cap, TTL
- `revoked` freezes instantly — faster than a credit-card freeze

### 2.2 FacilitatorSettlement

```
- settle(accountAddr, merchant, amount, nonce, sig)
    verify: signature valid + nonce unused + account.checkLimits passes
    execute: USDC account→merchant
    write: ReceiptsRegistry.log(...)
    replay protection: nonce recorded
```

- Open-source reference implementation; merchants self-deploy or use a public instance
- Aligned with official x402 spec (EIP-3009 transferWithAuthorization-style signatures)

### 2.3 ReceiptsRegistry

```
Receipt {
    accountAddr (address)
    merchant (address)
    amount (uint256)
    resourceHash (bytes32)    // content hash of purchased data/service
    timestamp (uint64)
    settlementTx (bytes32)
}
- log() callable only by registered settlement contracts
- verify(receiptId) view for console / third parties
```

- Resource hash makes receipts checkable: "paid but never delivered" becomes provable
- Merchant reputation derivable from receipt history (future: merchant scoring)

## 3. x402 Payment Loop

```
1. Agent → GET merchant API
2. Merchant ← 402 { price: $0.01 USDC, facilitator: 0xSettlement }
3. Agent signs payment credential (account session key)
4. Facilitator verifies → FacilitatorSettlement.settle() → settles on-chain
5. Merchant sees settlement proof → 200 { data }
6. Registry receipt generated automatically
```

- Payment credential = EIP-712 structured signature (merchant/amount/nonce/deadline) — tamper- and replay-proof
- Merchants only need to watch the on-chain settle event — no trust in the facilitator required

## 4. Security Model

| Threat | Defense |
|--------|---------|
| Agent key leak | loss capped at budget; owner revoke freezes |
| Payment credential replay | nonce + deadline |
| Malicious facilitator | merchant self-verifies via on-chain events; facilitator can't abscond with funds |
| Agent overspending | perTxMax + budget hard limits |
| Merchant takes payment, no delivery | resourceHash receipt as evidence |

## 5. Deployment Topology

| Network | Content | Purpose |
|---------|---------|---------|
| Arbitrum Sepolia | all contracts + mock merchant | development |
| **Arbitrum One mainnet** | all contracts + real USDC | **primary competition deployment** (reserved-slot key) |
