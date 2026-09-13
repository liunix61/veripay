# VeriPay Judge 问答预案 / Judge Q&A Prep

## Q1: x402 已有 HTTP 402 协议，为什么需要链上部分？

**A**: HTTP 402 解决"怎么付"，不解决"该不该付"。链上部分提供三件协议层没有的：
1. 支出上限的强制执行（协议层只能靠客户端自觉）
2. 不可抵赖的支付授权（EIP-712 签名 = 事后可审计的授权证据）
3. 链上收据（merchant/amount/resourceHash，第三方可独立对账）
facilitator 角色保持链下 —— 我们只把"授权与限额"钉在链上。

## Q2: 为什么 settle 是任何人可提交（relay-agnostic）？不怕滥用？

**A**: 签名绑定 account/merchant/amount/nonce/deadline/resourceHash 六要素，
改一字节验签失败；nonce 防重放；deadline 防旧签名重用。relay 只是搬运工，
无任何自由度。收益：Agent 不需要持有 ETH 付 gas —— 这是 x402 机器支付的关键体验。

## Q3: session key 和 owner 权限怎么划分？

**A**:
| | owner | session key |
|---|---|---|
| 能做 | 开户/充值/撤销/改 policy/换 key/扫尾 | **仅签支付授权** |
| 持有 | 用户（冷） | Agent 进程（热） |
最坏情况（session key 泄露）：损失 ≤ min(budget, 白名单可消耗额)，
且流向全部是白名单地址。owner key 永不在线。

## Q4: USDC 转账失败（比如账户余额不足）会怎样？

**A**: settle 整体 revert —— 原子性保证不会出现"收据写了钱没转"。
测试 `test_settle_overBudget` 验证边界：预算精确耗尽后再付直接 revert。

## Q5: 为什么不直接用 ERC-4337 智能账户？

**A**: 方向一致（账户抽象），我们做的是垂直切片：
1. 4337 是通用账户框架；VeriPay 是"机器支付限额"这一件事做到合约级强制
2. 4337 依赖 bundler/paymaster 基建；我们 settle 单合约可独立部署审计
3. 4337 兼容是 V2 选项（账户可以同时是 4337 account），不冲突

## Q6: 防重放为什么不用 EIP-712 的 deadline 就够？

**A**: deadline 只挡"过期后重放"，挡不住"有效期内重放"。
每账户 nonce 单调递增 + struct 内含 nonce → 同签名第二次必撞 NonceMismatch。
测试 `test_settle_replayReverts` 证明。

## Q7: 收据存链上成本谁出？高频小额支付 gas 划算吗？

**A**:
- Arbitrum One L2：单次 settle ~150k gas ≈ $0.01-0.02，支付场景可接受
- 高频场景 V2：收据批量锚定（Merkle root 定期上链），单笔摊薄到忽略不计
- 与"支付金额"比，gas 占比在 0.01-0.5%（$0.50 支付时最坏情况），可写进产品文档

## Q8: FollowerVault 跟单会不会变成杀猪盘放大器？

**A**: 这正是限额账户存在的意义 —— 跟随者不是把钱给 KOL，而是：
1. 资金锁在**自己的**限额 Vault 里
2. 只复制目标 Agent 的**已验证交易流**（VeriAgent 凭证先于交易）
3. 跟随者自己的 policy 独立生效（最大亏损熔断随时可触发）
KOL 拿不到资金托管权，只能"被跟随"。作恶空间被合约压缩到接近零 —— 
这恰好是比赛 "address a real problem" 的答案：社交跟单的信任问题。
