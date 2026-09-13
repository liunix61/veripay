# VeriPay — Agent 限额支付轨道（x402 结算）

> Arbitrum Open House Singapore Buildathon 2026 · Arbitrum One

**一句话**：给每个 AI Agent 开一个链上限额智能账户——预算、白名单、单笔上限、有效期全部合约强制；每笔支付有 EIP-712 授权签名和链上收据。

## 为什么需要它

Agent 自主付费调用 API/数据/算力（x402 模式）时，运营方的恐惧是：key 泄露 = 无限盗刷。VeriPay 把风控从"事后报警"变成"链上物理不可能"：

| 规则 | 合约强制 |
|---|---|
| 预算上限（如 $5/月） | ✅ 花完即停，链上余额守恒 |
| 商户白名单 | ✅ 非白名单地址直接 revert |
| 单笔上限 | ✅ 防一笔掏空 |
| 有效期 | ✅ 过期账户死亡 |
| 即时撤销 | ✅ owner 一键 revoke，秒级生效 |
| Session key 轮换 | ✅ 泄露 key 立即作废 |

## 架构

```
Agent 引擎                     链上
┌──────────────┐   EIP-712    ┌────────────────────────┐
│ PaymentClient │──签名──────▶│ FacilitatorSettlement  │
│ (session key) │             │  验签/nonce/防重放      │
└──────────────┘              │        ↓               │
                              │ AgentPayAccount        │
 任何人可代为提交(relay-agnostic)│  4 项硬限额 + revoke    │
                              │        ↓ USDC 转账      │
                              │ ReceiptsRegistry       │
                              │  (链上收据/审计)         │
└──────────────────────────────────────────────────────┘
```

**EIP-712 摘要跨语言互证**：`engine/eip712.py` 与合约内部摘要计算逐字节一致，同一向量在 pytest 与 forge 双端断言（`Eip712Parity.t.sol`）。

## 快速开始

```bash
cd contracts && forge test     # 29 tests（含 3 个跨语言奇偶校验）
cd .. && python3 -m pytest tests/ -q   # 7 tests
```

## V2 路线图：跟单钱包（FOMO 社交化交易）

比赛期交付信号订阅层；**FollowerVault 镜像跟单**（跟随者资金锁进限额 Vault，
复制目标 Agent 的已验证交易流）作为 V2 路线图——这正是 Promising Products
赛道 "Requesting funding" 的答案。详见 `docs/01-总体方案.md` 第 8/9 节。

## 文档

`docs/` 中英双语四件套：总体方案 / 系统架构 / 技术框架 / 核心流程。

## License

MIT
