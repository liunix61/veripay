"""VeriPay Facilitator — open-source, self-hostable x402 settlement relay.

The facilitator is TRUSTLESS by design: the agent's EIP-712 signature is the
authority. This service only (1) pre-checks limits via eth_call and (2) relays
the signed settlement, paying gas from its own relayer key. It can never move
funds the agent did not explicitly authorize, and merchants can bypass it
entirely by submitting settle() themselves.

Endpoints:
    GET  /health                     service + settlement config
    POST /verify   {auth}            pre-flight limit check (eth_call)
    POST /settle   {auth, signature}  relay the settlement on-chain

Config (env):
    VERIPAY_RPC          JSON-RPC endpoint (unset → mock mode)
    VERIPAY_SETTLEMENT   FacilitatorSettlement address
    VERIPAY_CHAIN_ID     chain id (default 421614)
    VERIPAY_RELAYER_KEY  relayer EOA private key (pays gas; never holds funds)
    VERIPAY_PORT         listen port (default 8546)

No framework, no web3.py — stdlib http.server + raw JSON-RPC + eth_account
for signing + eth_abi for encoding. One file, self-contained, auditable.
"""

from __future__ import annotations

import json
import os
import time
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from eth_abi.abi import encode as abi_encode
from eth_account import Account
from eth_hash.auto import keccak

# ── ABI fragments (verified against FacilitatorSettlement.sol) ──────────────
_TUPLE = "(address,address,uint256,uint256,uint256,bytes32)"
SETTLE_SELECTOR = keccak(f"settle({_TUPLE},bytes)".encode())[:4]
VERIFY_SELECTOR = keccak(f"verify({_TUPLE})".encode())[:4]


def settle_calldata(auth: tuple, signature: bytes) -> bytes:
    """Exact calldata for FacilitatorSettlement.settle(auth, sig)."""
    return SETTLE_SELECTOR + abi_encode([_TUPLE, "bytes"], [auth, signature])


def verify_calldata(auth: tuple) -> bytes:
    """Exact calldata for FacilitatorSettlement.verify(auth)."""
    return VERIFY_SELECTOR + abi_encode([_TUPLE], [auth])


def auth_tuple(auth: dict) -> tuple:
    return (
        auth["account"], auth["merchant"], int(auth["amount"]),
        int(auth["nonce"]), int(auth["deadline"]),
        bytes.fromhex(auth["resourceHash"].removeprefix("0x")),
    )


class Facilitator:
    def __init__(self, rpc: str, settlement: str, chain_id: int, relayer_key: str):
        self.rpc = rpc
        self.settlement = settlement
        self.chain_id = chain_id
        self.mock = not rpc
        self.relayer = Account.from_key(relayer_key) if relayer_key else None

    # ── JSON-RPC plumbing ───────────────────────────────────────────────
    def _rpc(self, method: str, params: list) -> dict:
        body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
        req = urllib.request.Request(
            self.rpc, data=body, headers={"Content-Type": "application/json"}
        )
        with urllib.request.urlopen(req, timeout=30) as r:
            return json.loads(r.read())

    def _eth_call(self, data: str) -> str:
        res = self._rpc("eth_call", [{"to": self.settlement, "data": data}, "latest"])
        if "error" in res:
            raise RuntimeError(res["error"].get("message", "eth_call failed"))
        return res["result"]

    # ── endpoints ───────────────────────────────────────────────────────
    def verify(self, auth: dict) -> dict:
        """Pre-flight: can this payment settle right now?"""
        if self.mock:
            return self._mock_verify(auth)
        data = "0x" + verify_calldata(auth_tuple(auth)).hex()
        out = self._eth_call(data)
        ok = int(out[2:66], 16) == 1
        reason = bytes.fromhex(out[66:130]).rstrip(b"\x00").decode(errors="replace")
        return {"ok": ok, "reason": reason if not ok else ""}

    def settle(self, auth: dict, signature: str) -> dict:
        """Relay the agent-signed settlement. Gas paid by relayer key."""
        pre = self.verify(auth)
        if not pre["ok"]:
            return {"ok": False, "reason": pre["reason"]}
        if self.mock:
            fake_tx = "0x" + keccak(
                json.dumps([auth, signature], sort_keys=True).encode()
            ).hex()
            return {"ok": True, "txHash": fake_tx, "mode": "mock"}

        if self.relayer is None:
            return {"ok": False, "reason": "RELAYER_KEY_NOT_CONFIGURED"}

        sig_bytes = bytes.fromhex(signature.removeprefix("0x"))
        data = "0x" + settle_calldata(auth_tuple(auth), sig_bytes).hex()
        nonce = int(self._rpc("eth_getTransactionCount",
                              [self.relayer.address, "latest"])["result"], 16)
        gas_price = int(self._rpc("eth_gasPrice", [])["result"], 16)
        tx = {
            "to": self.settlement, "data": data, "value": 0,
            "nonce": nonce, "gas": 500_000,
            "gasPrice": int(gas_price * 1.2),  # margin for base-fee moves
            "chainId": self.chain_id,
        }
        signed = self.relayer.sign_transaction(tx)
        res = self._rpc("eth_sendRawTransaction", ["0x" + signed.raw_transaction.hex()])
        if "error" in res:
            return {"ok": False, "reason": res["error"].get("message", "send failed")}
        return {"ok": True, "txHash": res["result"], "mode": "live"}

    def _mock_verify(self, auth: dict) -> dict:
        """Local limit approximation when no RPC is configured (demo only)."""
        if int(auth["deadline"]) < time.time():
            return {"ok": False, "reason": "EXPIRED"}
        if int(auth["amount"]) <= 0:
            return {"ok": False, "reason": "ZERO_AMOUNT"}
        return {"ok": True, "reason": ""}

    def health(self) -> dict:
        return {
            "ok": True, "mode": "mock" if self.mock else "live",
            "settlement": self.settlement, "chainId": self.chain_id,
            "relayer": self.relayer.address if self.relayer else None,
        }


def make_handler(fac: Facilitator):
    class Handler(BaseHTTPRequestHandler):
        def _send(self, code: int, payload: dict):
            body = json.dumps(payload).encode()
            self.send_response(code)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def do_GET(self):
            if self.path == "/health":
                self._send(200, fac.health())
            else:
                self._send(404, {"error": "not found"})

        def do_POST(self):
            try:
                n = int(self.headers.get("Content-Length", 0))
                body = json.loads(self.rfile.read(n) or b"{}")
                if self.path == "/verify":
                    self._send(200, fac.verify(body.get("auth", body)))
                elif self.path == "/settle":
                    self._send(200, fac.settle(body["auth"], body["signature"]))
                else:
                    self._send(404, {"error": "not found"})
            except Exception as e:  # noqa: BLE001 — surface as JSON, never crash
                self._send(400, {"error": str(e)})

        def log_message(self, fmt: str, *a) -> None:  # quiet by default
            pass

    return Handler


def from_env() -> Facilitator:
    return Facilitator(
        rpc=os.environ.get("VERIPAY_RPC", ""),
        settlement=os.environ.get("VERIPAY_SETTLEMENT", "0x" + "00" * 20),
        chain_id=int(os.environ.get("VERIPAY_CHAIN_ID", "421614")),
        relayer_key=os.environ.get("VERIPAY_RELAYER_KEY", ""),
    )


def main() -> None:
    port = int(os.environ.get("VERIPAY_PORT", "8546"))
    fac = from_env()
    server = ThreadingHTTPServer(("0.0.0.0", port), make_handler(fac))
    mode = "mock" if fac.mock else "live"
    print(f"veripay facilitator ({mode}) listening on :{port}")
    server.serve_forever()


if __name__ == "__main__":
    main()
