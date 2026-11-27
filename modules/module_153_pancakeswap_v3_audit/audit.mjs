#!/usr/bin/env node
/**
 * CYBRA module 153 — PancakeSwap V3 read-only audit.
 * No signer, wallet, .env loader, approve, mint, swap, transfer or tx-send code.
 */
import { isAddress, getAddress, id, ZeroAddress } from "ethers";

export function sortTokenMetadata(tokenA, tokenB) {
  for (const token of [tokenA, tokenB]) {
    if (!isAddress(token.address)) throw new Error("Invalid token address");
    if (!Number.isInteger(token.decimals) || token.decimals < 0 || token.decimals > 255) {
      throw new Error("Token decimals must be an integer from 0 to 255");
    }
  }
  const a = { ...tokenA, address: getAddress(tokenA.address) };
  const b = { ...tokenB, address: getAddress(tokenB.address) };
  if (a.address.toLowerCase() === b.address.toLowerCase()) {
    throw new Error("Pool tokens must be different addresses");
  }
  return a.address.toLowerCase() < b.address.toLowerCase()
    ? { token0: a, token1: b }
    : { token0: b, token1: a };
}

export function auditTicks({ tickLower, tickUpper, tickSpacing }) {
  const errors = [];
  if (!Number.isInteger(tickLower) || !Number.isInteger(tickUpper)) {
    errors.push("Ticks must be integers");
  } else {
    if (tickLower < -887272 || tickUpper > 887272) errors.push("Tick outside V3 global bounds");
    if (tickLower >= tickUpper) errors.push("tickLower must be less than tickUpper");
  }
  if (!Number.isInteger(tickSpacing) || tickSpacing <= 0) {
    errors.push("A verified positive tickSpacing is required");
  } else if (Number.isInteger(tickLower) && Number.isInteger(tickUpper)) {
    if (tickLower % tickSpacing !== 0) errors.push("tickLower is not aligned to tickSpacing");
    if (tickUpper % tickSpacing !== 0) errors.push("tickUpper is not aligned to tickSpacing");
  }
  return { ok: errors.length === 0, errors };
}

export function classifyTransferLog(log, positionManager) {
  const topic = id("Transfer(address,address,uint256)").toLowerCase();
  if (!log.topics?.[0] || log.topics[0].toLowerCase() !== topic) return null;
  const nft = log.topics.length === 4;
  const from = nft ? "0x" + log.topics[1].slice(-40) : null;
  const to = nft ? "0x" + log.topics[2].slice(-40) : null;
  const tokenId = nft ? BigInt(log.topics[3]).toString() : null;
  const isMint = nft && from.toLowerCase() === ZeroAddress.toLowerCase();
  const managerMatch = !positionManager || log.address.toLowerCase() === positionManager.toLowerCase();
  return {
    contract: log.address,
    kind: nft ? "erc721-transfer" : "erc20-transfer",
    from, to, tokenId,
    isNftMint: isMint && managerMatch,
    positionManagerMatch: managerMatch
  };
}

export async function rpcCall(rpcUrl, method, params = []) {
  const response = await fetch(rpcUrl, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ jsonrpc: "2.0", id: 1, method, params })
  });
  if (!response.ok) throw new Error("RPC HTTP " + response.status);
  const payload = await response.json();
  if (payload.error) throw new Error(payload.error.message || "RPC error");
  return payload.result;
}

export async function auditTransaction({ rpcUrl, txHash, positionManager }) {
  if (!/^0x[0-9a-fA-F]{64}$/.test(txHash || "")) throw new Error("A valid 32-byte transaction hash is required");
  if (positionManager && !isAddress(positionManager)) throw new Error("Invalid position manager address");
  const [chainId, tx, receipt] = await Promise.all([
    rpcCall(rpcUrl, "eth_chainId"),
    rpcCall(rpcUrl, "eth_getTransactionByHash", [txHash]),
    rpcCall(rpcUrl, "eth_getTransactionReceipt", [txHash])
  ]);
  if (!tx) return { chainId, found: false, confirmed: false, status: "NOT_FOUND" };
  if (!receipt) return {
    chainId, found: true, confirmed: false, status: "PENDING_OR_RECEIPT_UNAVAILABLE",
    from: tx.from, to: tx.to, blockNumber: tx.blockNumber
  };
  const events = (receipt.logs || []).map(log => classifyTransferLog(log, positionManager)).filter(Boolean);
  const nftMints = events.filter(event => event.isNftMint);
  const status = receipt.status === "0x1" ? "SUCCESS" : "FAILED";
  return {
    chainId, found: true, confirmed: true, status,
    from: tx.from, to: tx.to,
    blockNumber: Number(BigInt(receipt.blockNumber)),
    gasUsed: BigInt(receipt.gasUsed).toString(),
    logsCount: (receipt.logs || []).length,
    erc20Transfers: events.filter(event => event.kind === "erc20-transfer").length,
    nftTransfers: events.filter(event => event.kind === "erc721-transfer").length,
    nftMints,
    note: status === "SUCCESS"
      ? "Receipt succeeded; verify NFT contract, tokenId, ownerOf(tokenId) and positions(tokenId) separately."
      : "Receipt failed; network fees may still have been charged. Do not resubmit automatically."
  };
}

function parseArgs(argv) {
  const args = {};
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === "--tx") args.txHash = argv[++i];
    else if (argv[i] === "--position-manager") args.positionManager = argv[++i];
    else if (argv[i] === "--rpc") args.rpcUrl = argv[++i];
    else if (argv[i] === "--help") args.help = true;
    else throw new Error("Unknown argument: " + argv[i]);
  }
  return args;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.help) {
    console.log("Usage: node audit.mjs --tx 0xHASH [--rpc RPC_URL] [--position-manager ADDRESS]");
    return;
  }
  const rpcUrl = args.rpcUrl || process.env.BSC_RPC_URL || "https://bsc-rpc.publicnode.com";
  const txHash = args.txHash || process.env.CYBRA_AUDIT_TX;
  if (!txHash) throw new Error("Pass --tx or set CYBRA_AUDIT_TX; no transaction is submitted.");
  const result = await auditTransaction({ rpcUrl, txHash, positionManager: args.positionManager });
  console.log(JSON.stringify(result, null, 2));
  if (result.chainId !== "0x38") {
    console.error("WARNING: RPC is not BNB Smart Chain mainnet (chainId 56).");
    process.exitCode = 2;
  }
  if (result.status === "FAILED") process.exitCode = 1;
}
if (process.argv[1] && import.meta.url === new URL(process.argv[1], "file://").href) {
  main().catch(error => {
    console.error("READ-ONLY AUDIT ERROR: " + error.message);
    process.exitCode = 1;
  });
}
