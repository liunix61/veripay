# 07 — 组合叙事：VeriAgent × VeriPay（AI Agent 金融原语全栈）

> Arbitrum Open House Singapore Buildathon 2026 · Promising Products（AI agents + new financial primitives）

## 一句话

**VeriAgent 审计 Agent 的每一次投资决策，VeriPay 审计 Agent 的每一笔付费支出——AI Agent 金融活动的资金两端全部链上可验证。**

## 双项目定位

| | VeriAgent（Robinhood Chain track） | VeriPay（Arbitrum One track） |
|---|---|---|
| 解决的问题 | Agent 交易决策凭什么可信？ | Agent 支付凭什么不被盗刷？ |
| 核心原语 | 决策凭证先于交易（四哈希+两阶段 record→bindTx） | 限额智能账户（EIP-712 授权+链上收据） |
| 资产方向 | bStocks/RWA 代币化资产管理（SEC TSV 合规对齐） | USDC x402 机器支付结算 |
| 审计形态 | 决策依据：action/reason/dataSource/model 四哈希 | 支付依据：商户/金额/资源哈希收据 |
| 约束引擎 | Vault policy：白名单/仓位上限/日亏损熔断/冷却/频率 | Account policy：预算/白名单/单笔上限/有效期/撤销 |

两个项目共用同一设计哲学：**约束写进合约，证据写进链，顺序可独立验证**。

## 组合场景：一个 Agent 的完整金融生命周期

```
┌─ 决策侧（VeriAgent）────────────────────────────────┐
│  市场快照 → Jev/NanoJev 决策 → 四哈希凭证上链        │
│  → Vault 约束内执行 bStocks 调仓 → bindTx 回绑       │
│  （HALTED 时段硬拒；股息 dividend_ack 双重审计）      │
└──────────────────────┬───────────────────────────────┘
                       │ Agent 需要付费：行情 API、数据源、交易费
┌─ 支付侧（VeriPay）───▼───────────────────────────────┐
│  x402 请求 → EIP-712 session key 授权签名            │
│  → FacilitatorSettlement 验签/防重放                  │
│  → AgentPayAccount 硬限额校验（预算/白名单/单笔上限）  │
│  → USDC 结算 + ReceiptsRegistry 链上收据              │
└──────────────────────────────────────────────────────┘
```

一个 AI Agent 的每次投资决策有决策凭证，每次数据采购有支付收据——**资金进出行全栈可审计**。

## Jev/NanoJev 双轨决策接入

决策模型层不锁定供应商：

- **Jev**（TypeSafe System One）：商业 API，typed decisions + calibrated confidence
- **NanoJev**（开源，liunix61/NanoJev fork）：Qwen3-0.6B + decision heads，本地 `POST /api/evaluate` serving，零 API 费用

两者输出同一 `JevDecision` 契约（action + confidence），进入同一条 VeriAgent 凭证流水线；`model_id`/`modelHash` 在链上区分血统。**开源决策模型意味着审计可复现**——任何人都能本地加载同一权重复演被审计的决策（闭源 API 做不到）。

配套：VeriPay 的限额账户为 Agent 调用商业决策 API 提供预算约束（如 Jev API $5/月上限，花完即停，链上物理不可能超支）。

## 评审叙事对位

| Buildathon 评分项 | 组合项目的回答 |
|---|---|
| 合约质量 | 双项目 114 forge tests（84+30）+跨语言哈希/EIP-712 互证（同一向量 pytest×forge 双端断言） |
| PMF | RWA 代币化（SEC 9/17 豁免令）+ AI Agent 支付（x402）都是 2026 确定性赛道；Jev 生态 3 天 1.1k stars 证明 Agent 决策基础设施需求爆发 |
| 创新性 | "决策凭证"与"限额支付账户"都是业界没有的原语；双轨决策模型审计（含开源血统可复现）为首创 |
| 真实问题 | Agent 资管信任缺失+Agent 支付盗刷恐惧——运营方的真实顾虑被合约物理性消除 |

## Repo 与测试

- VeriAgent: `liunix61/veriagent` — 84 forge + 59 pytest（RWA 合规层+Jev/NanoJev 审计层）
- VeriPay: `liunix61/veripay` — 30 forge + 15 pytest（EIP-712 结算+FalseTransfer 修复）
