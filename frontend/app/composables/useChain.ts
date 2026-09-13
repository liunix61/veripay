import {
  createPublicClient, http, type PublicClient,
} from "viem";
import { arbitrumSepolia } from "viem/chains";

export const accountAbi = [
  {
    type: "event", name: "PaymentExecuted",
    inputs: [
      { name: "merchant", type: "address", indexed: true },
      { name: "amount", type: "uint256", indexed: false },
      { name: "reason", type: "bytes32", indexed: false },
    ],
  },
  {
    type: "function", name: "remaining", stateMutability: "view",
    inputs: [], outputs: [{ name: "", type: "uint256" }],
  },
  {
    type: "function", name: "spent", stateMutability: "view",
    inputs: [], outputs: [{ name: "", type: "uint256" }],
  },
  {
    type: "function", name: "getPolicy", stateMutability: "view",
    inputs: [],
    outputs: [
      { name: "budget", type: "uint256" },
      { name: "perTxMax", type: "uint256" },
      { name: "expiresAt", type: "uint64" },
    ],
  },
] as const;

export const registryAbi = [
  {
    type: "event", name: "ReceiptLogged",
    inputs: [
      { name: "receiptId", type: "uint256", indexed: true },
      { name: "account", type: "address", indexed: true },
      { name: "merchant", type: "address", indexed: true },
      { name: "amount", type: "uint256", indexed: false },
      { name: "resourceHash", type: "bytes32", indexed: false },
    ],
  },
] as const;

declare module "@nuxt/schema" {
  interface RuntimeConfig {
    public: {
      chainRpc?: string; chainId?: number;
      settlementAddress?: string; registryAddress?: string;
      accountAddress?: string;
    };
  }
}

export function useChain() {
  const cfg = useRuntimeConfig().public as {
    chainRpc?: string; chainId?: number;
    settlementAddress?: string; registryAddress?: string;
    accountAddress?: string;
  };
  let client: PublicClient | null = null;
  const getClient = (): PublicClient => {
    if (!client) {
      client = createPublicClient({
        chain: { ...arbitrumSepolia, id: cfg.chainId ?? 421614 },
        transport: http(cfg.chainRpc),
      }) as PublicClient;
    }
    return client;
  };
  const connected = computed(() => Boolean(cfg.chainRpc));
  return { cfg, getClient, connected };
}
