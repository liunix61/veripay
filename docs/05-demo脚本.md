# VeriPay Demo 脚本（3 分钟）/ Demo Script (3 min)

## 0:00–0:20 — Hook

**中文**：Agent 自主付费调用 API，key 泄露 = 无限盗刷？我们把风控从"事后报警"
变成"链上物理不可能" —— 预算、白名单、单笔上限，全部合约强制。

**EN**: Agents pay autonomously for APIs. Leaked key = unlimited drain? We make
overspending physically impossible on-chain — budget, whitelist, per-tx cap,
all contract-enforced.

## 0:20–1:00 — 机制（合约）

屏幕：`AgentPayAccount.sol` checkLimits 代码

1. `createAccount(sessionKey, policy)` — 一键开限额账户（budget/白名单/单笔上限/有效期）
2. Agent 签 EIP-712 PaymentAuth → 任何人可代提交（relay-agnostic）
3. `FacilitatorSettlement.settle()`：验签 → nonce 防重放 → checkLimits 4 规则 → USDC 转账 → 收据上链
4. 强调：**签名来自 session key，不是 owner key** —— 泄露秒级轮换/撤销

## 1:00–1:40 — Demo（终端实拍）

```bash
forge test        # 29 tests：happy path + 重放/过期/错签名/旧key/超单笔/超预算/撤销
```
重点演两个攻击测试：
- `test_settle_replayReverts` —— 同签名二次提交直接 revert
- `test_settle_oldKeyInvalidAfterRotation` —— 轮换后旧 key 签名作废

Python 侧：
```bash
pytest tests/ -q  # 7 tests：EIP-712 摘要与合约逐字节互证
```

## 1:40–2:20 — 收据与审计

屏幕：`ReceiptsRegistry.sol`
- 每笔支付链上收据（account/merchant/amount/resourceHash）
- 第三方可独立审计：这个 Agent 把钱付给了谁、买了什么资源、是否超限

## 2:20–3:00 — 收尾 + V2

- V2 路线图：FollowerVault 镜像跟单钱包（FOMO 社交化交易）——
  跟随者资金锁进限额 Vault，复制目标 Agent 的已验证交易流
- 结束语：**Give agents a wallet they cannot abuse.**

## 录制清单

- [ ] forge test 29 全绿（重点两条攻击测试）
- [ ] pytest 7 全绿（含摘要奇偶向量）
- [ ] AgentPayAccount.sol checkLimits 函数滚动
- [ ] FacilitatorSettlement.sol settle 流程滚动
- [ ] 收据 verify() 演示
