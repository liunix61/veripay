# VeriPay Technical Framework

> Created: 2026-09-13 | Related: 01-solution-overview / 02-system-architecture / 04-core-flows

---

## 1. Repository Structure (same monorepo as VeriAgent, separate directory)

```
veripay/
├── contracts/                  # Foundry
│   ├── src/
│   │   ├── AgentPayAccount.sol     # account + factory
│   │   ├── FacilitatorSettlement.sol
│   │   ├── ReceiptsRegistry.sol
│   │   └── interfaces/
│   ├── test/                   # unit + fuzz + attack PoCs
│   └── script/Deploy.s.sol
├── facilitator/                # open-source settlement service (FastAPI)
│   ├── main.py                 # /verify /settle endpoints
│   └── merchant_sdk.py         # merchant integration SDK (Python)
├── engine/                     # reuses veriagent/engine/x402_client.py
├── frontend/                   # Nuxt4 spending console (shared frontend)
└── docs/                       # bilingual
```

## 2. Tech Stack

| Component | Choice | Notes |
|-----------|--------|-------|
| Contracts | Solidity ^0.8.24 + Foundry | custom errors + fuzz |
| Stablecoin | USDC (native on Arbitrum One) | 6 decimals |
| Signatures | EIP-712 structured | payment credential: merchant/amount/nonce/deadline |
| Transfer auth | EIP-3009 transferWithAuthorization pattern | x402-spec aligned |
| Facilitator | FastAPI open-source service | self-hostable or public instance |
| Frontend | Nuxt4 + viem | components shared with VeriAgent |
| Tests | forge + pytest + anvil mainnet fork | real USDC behavior verified on fork |

## 3. Key Contract Interfaces

```solidity
// AgentPayAccount.sol
function createAccount(AccountPolicy calldata p) external returns (address account);
function authorizePayment(address merchant, uint256 amount, uint256 nonce,
                           uint256 deadline, bytes calldata sig) external;
function checkLimits(address merchant, uint256 amount)
        external view returns (bool ok, bytes32 reason);
function topUp(address account, uint256 amount) external;   // owner
function revoke(address account) external;                  // owner instant freeze

// FacilitatorSettlement.sol
function settle(address account, address merchant, uint256 amount,
                uint256 nonce, uint256 deadline, bytes calldata sig)
        external returns (bytes32 receiptId);
function registerFacilitator(address f) external;           // owner governance

// ReceiptsRegistry.sol
function log(address account, address merchant, uint256 amount,
             bytes32 resourceHash) external returns (uint256 receiptId);
function verify(uint256 receiptId) external view returns (Receipt memory);
```

## 4. Limit Check Order (AgentPayAccount core)

1. **TTL**: `block.timestamp < expiresAt`
2. **Pause**: `!paused && !revoked`
3. **Whitelist**: `merchantWhitelist[merchant]`
4. **Per-tx cap**: `amount ≤ perTxMax`
5. **Budget**: `spent + amount ≤ budget`

Any failure reverts with a reason; the agent self-corrects or gives up.

## 5. EIP-712 Payment Credential

```solidity
PaymentAuth(
    address account,
    address merchant,
    uint256 amount,
    uint256 nonce,
    uint256 deadline
)
// domain: {name: "VeriPay", version: "1", chainId: 1, verifyingContract: Settlement}
```

- Domain separator includes chainId + contract address → no cross-chain/contract replay
- Per-account incrementing nonce; deadline bounds credential lifetime

## 6. Facilitator Service

```
POST /verify  {paymentAuth, sig} → verify sig + simulate checkLimits (eth_call)
POST /settle  {paymentAuth, sig} → send settle tx → return receiptId + txHash
GET  /receipt/{id}               → read on-chain receipt
```

- Merchant SDK: 3-line integration (`paywall(verify_url, price)` decorator)
- The facilitator itself need not be trusted: settlement is on-chain; merchants watch events

## 7. Test Strategy

| Layer | Content |
|-------|---------|
| forge unit | each of the 5 limit rejection paths + happy path + nonce replay protection |
| forge fuzz | amount/time/nonce boundaries |
| attack PoCs | credential replay / unauthorized merchant / overspend / expired-TTL payment |
| pytest | facilitator API + merchant SDK |
| anvil fork | full loop with real USDC contract on mainnet fork |

## 8. Gas Budget (Arbitrum One)

| Operation | Est. gas | Cost |
|-----------|---------|------|
| settle() | ~150k | <$0.01 |
| createAccount() | ~200k | <$0.01 |
| log() | ~60k | ~$0.003 |

**$0.01-level micropayments are economically viable** — the project's core thesis.
