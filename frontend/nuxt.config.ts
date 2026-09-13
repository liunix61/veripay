export default defineNuxtConfig({
  ssr: false,
  devtools: { enabled: false },
  compatibilityDate: "2025-01-01",
  runtimeConfig: {
    public: {
      chainRpc: "",
      chainId: 421614,
      settlementAddress: "",
      registryAddress: "",
      accountAddress: "",
    },
  },
});
