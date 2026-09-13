<template>
  <div class="panel">
    <h2>链上收据 / Receipts
      <span style="float: right" class="pill" :class="mode === 'chain' ? 'ok' : 'warn'">
        {{ mode === "chain" ? "ON-CHAIN" : "DEMO" }}
      </span>
    </h2>
    <p style="color: var(--dim); font-size: 12px; margin-top: 0">
      每笔 x402 结算写入 ReceiptsRegistry —— 商户交付纠纷时，
      <code>verify(receiptId)</code> 就是对账凭据，双方都不需要信任对方的账本。
    </p>
    <table>
      <thead>
        <tr><th>id</th><th>account</th><th>merchant</th><th>amount</th><th>resource hash</th></tr>
      </thead>
      <tbody>
        <tr v-for="r in receipts" :key="r.id">
          <td>#{{ r.id }}</td>
          <td>{{ r.account }}</td>
          <td>{{ r.merchant }}</td>
          <td>${{ r.amount }}</td>
          <td><span class="hash">{{ r.resourceHash }}</span></td>
        </tr>
        <tr v-if="!receipts.length">
          <td colspan="5" style="color: var(--dim)">no receipts</td>
        </tr>
      </tbody>
    </table>
  </div>
</template>

<script setup lang="ts">
const { getClient, cfg, connected } = useChain();

const mode = ref<"chain" | "demo">("demo");

interface Receipt {
  id: string; account: string; merchant: string;
  amount: string; resourceHash: string;
}

const receipts = ref<Receipt[]>([
  { id: "1", account: "0xA11A…c0de", merchant: "0x9999…9999",
    amount: "0.01", resourceHash: "0xab12…34cd" },
  { id: "2", account: "0xA11A…c0de", merchant: "0x8888…8888",
    amount: "0.02", resourceHash: "0xef56…7890" },
]);

const short = (s: unknown) => String(s).slice(0, 8) + "…" + String(s).slice(-4);

onMounted(async () => {
  const registry = (cfg.registryAddress as string) || "";
  if (!connected.value || !registry.startsWith("0x")) return; // keep demo
  try {
    const c = getClient();
    const logs = await c.getContractEvents({
      address: registry as `0x${string}`,
      abi: registryAbi, eventName: "ReceiptLogged",
      fromBlock: 0n, toBlock: "latest",
    });
    receipts.value = logs.map((l: any) => ({
      id: String(l.args.receiptId),
      account: short(l.args.account),
      merchant: short(l.args.merchant),
      amount: (Number(l.args.amount) / 1e6).toFixed(2),
      resourceHash: String(l.args.resourceHash).slice(0, 10) + "…",
    }));
    mode.value = "chain";
  } catch {
    // stay on demo
  }
});
</script>
