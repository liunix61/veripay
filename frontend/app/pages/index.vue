<template>
  <main>
    <h1>VeriPay — Agent 支付控制台</h1>
    <p style="color: var(--dim); font-size: 13px">
      限额智能账户 + x402 结算 + 链上收据 · Agent 永远碰不到你的信用卡
    </p>

    <section>
      <SpendPanel />
    </section>

    <section>
      <ReceiptsExplorer />
    </section>

    <section class="panel">
      <h2>架构 / How it works</h2>
      <pre style="font-size: 12px; color: var(--dim); overflow-x: auto">Agent 签 PaymentAuth(EIP-712)
  → Facilitator 预检 checkLimits (eth_call)
  → settle() 合约验签 + 重查限额
  → AgentPayAccount 付 USDC 给商户
  → ReceiptsRegistry 写收据 (商户/金额/资源hash)
  → 任何人 verify(receiptId) 对账</pre>
    </section>
  </main>
</template>

<script setup lang="ts">
useHead({ title: "VeriPay — Agent Payment Console" });
</script>
