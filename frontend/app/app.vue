<template>
  <NuxtPage />
</template>

<style>
:root {
  --bg: #0b0e14; --panel: #141824; --border: #232a3b;
  --text: #e6e9f0; --dim: #8b93a7;
  --accent: #2775ca;  /* USDC blue */
  --ok: #1f9d63; --bad: #d64545; --warn: #c9a227;
}
body { margin: 0; background: var(--bg); color: var(--text);
  font-family: ui-monospace, "SF Mono", Menlo, monospace; }
main { max-width: 1080px; margin: 0 auto; padding: 32px 20px; }
h1 { font-size: 22px; }
h2 { font-size: 15px; margin: 0 0 12px; }
.panel { background: var(--panel); border: 1px solid var(--border);
  border-radius: 10px; padding: 18px; margin-bottom: 18px; }
table { width: 100%; border-collapse: collapse; font-size: 13px; }
th, td { text-align: left; padding: 6px 8px; border-bottom: 1px solid var(--border); }
th { color: var(--dim); font-weight: 500; }
.pill { padding: 2px 8px; border-radius: 999px; font-size: 11px; }
.pill.ok { background: rgba(39,117,202,.15); color: var(--accent); }
.pill.warn { background: rgba(201,162,39,.15); color: var(--warn); }
.pill.bad { background: rgba(214,69,69,.15); color: var(--bad); }
.hash { color: var(--dim); font-size: 11px; }
</style>
