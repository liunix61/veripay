<template>
  <div class="panel">
    <h2>预算与支出 / Budget & Spend
      <span style="float: right" class="pill" :class="mode === 'chain' ? 'ok' : 'warn'">
        {{ mode === "chain" ? "ON-CHAIN" : "DEMO" }}
      </span>
    </h2>
    <table>
      <tbody>
        <tr>
          <th>budget</th><th>spent</th><th>remaining</th>
          <th>per-tx cap</th><th>expires</th>
        </tr>
        <tr>
          <td>${{ fmt(view.budget) }}</td>
          <td>${{ fmt(view.spent) }}</td>
          <td>
            <span class="pill" :class="view.budget - view.spent > 0 ? 'ok' : 'bad'">
              ${{ fmt(view.budget - view.spent) }}
            </span>
          </td>
          <td>${{ fmt(view.perTxMax) }}</td>
          <td>{{ view.expiresLabel }}</td>
        </tr>
      </tbody>
    </table>
    <div style="margin-top: 10px; background: var(--border); border-radius: 4px; height: 8px">
      <div :style="{
        width: pct + '%', height: '8px', borderRadius: '4px',
        background: pct > 90 ? 'var(--bad)' : 'var(--accent)',
      }" />
    </div>
    <p style="color: var(--dim); font-size: 11px; margin-bottom: 0">
      已用 {{ pct.toFixed(0) }}% —— 超预算/白名单外/TTL 过期由合约拒绝，Agent 无法绕过
    </p>

    <h2 style="margin-top: 18px">支付流水 / Payments</h2>
    <table>
      <thead>
        <tr><th>merchant</th><th>amount</th><th>status</th></tr>
      </thead>
      <tbody>
        <tr v-for="(p, i) in payments" :key="i">
          <td>{{ p.merchant }}</td>
          <td>${{ fmt(p.amount) }}</td>
          <td><span class="pill ok">settled</span></td>
        </tr>
        <tr v-if="!payments.length">
          <td colspan="3" style="color: var(--dim)">no payments</td>
        </tr>
      </tbody>
    </table>
  </div>
</template>

<script setup lang="ts">
const { getClient, cfg, connected } = useChain();

const mode = ref<"chain" | "demo">("demo");

const view = ref({
  budget: 5, spent: 1.23, perTxMax: 1,
  expiresLabel: "48h window",
});
const payments = ref<{ merchant: string; amount: number }[]>([
  { merchant: "coinmarketcap.eth", amount: 0.01 },
  { merchant: "weather-oracle.eth", amount: 0.02 },
  { merchant: "coinmarketcap.eth", amount: 1.20 },
]);

const fmt = (v: number) => v.toFixed(2);
const pct = computed(() =>
  view.value.budget > 0 ? (view.value.spent / view.value.budget) * 100 : 0
);

onMounted(async () => {
  const account = (cfg.accountAddress as string) || "";
  if (!connected.value || !account.startsWith("0x")) return; // keep demo
  try {
    const c = getClient();
    const [budget, perTxMax, expiresAt] = await c.readContract({
      address: account as `0x${string}`,
      abi: accountAbi, functionName: "getPolicy",
    });
    const spent = await c.readContract({
      address: account as `0x${string}`,
      abi: accountAbi, functionName: "spent",
    });
    const logs = await c.getContractEvents({
      address: account as `0x${string}`,
      abi: accountAbi, eventName: "PaymentExecuted",
      fromBlock: 0n, toBlock: "latest",
    });
    view.value = {
      budget: Number(budget) / 1e6,
      spent: Number(spent) / 1e6,
      perTxMax: Number(perTxMax) / 1e6,
      expiresLabel: new Date(Number(expiresAt) * 1000).toISOString().slice(0, 16),
    };
    payments.value = logs.map((l: any) => ({
      merchant: String(l.args.merchant),
      amount: Number(l.args.amount) / 1e6,
    }));
    mode.value = "chain";
  } catch {
    // stay on demo
  }
});
</script>
