import test from "node:test";
import assert from "node:assert/strict";
import { sortTokenMetadata, auditTicks, classifyTransferLog } from "../audit.mjs";
import { id, ZeroAddress } from "ethers";

test("sorting keeps decimals attached to their token", () => {
  const a = { address: "0x00000000000000000000000000000000000000b2", decimals: 18, symbol: "B" };
  const b = { address: "0x00000000000000000000000000000000000000a1", decimals: 6, symbol: "A" };
  const { token0, token1 } = sortTokenMetadata(a, b);
  assert.equal(token0.symbol, "A");
  assert.equal(token0.decimals, 6);
  assert.equal(token1.symbol, "B");
  assert.equal(token1.decimals, 18);
});
test("rejects same token and invalid decimals", () => {
  const a = { address: "0x00000000000000000000000000000000000000a1", decimals: 18 };
  assert.throws(() => sortTokenMetadata(a, a), /different addresses/);
  assert.throws(() => sortTokenMetadata({ ...a, decimals: 300 }, { ...a, address: "0x00000000000000000000000000000000000000b2" }), /decimals/);
});
test("checks tick spacing and bounds", () => {
  assert.equal(auditTicks({ tickLower: -100, tickUpper: 100, tickSpacing: 10 }).ok, true);
  assert.equal(auditTicks({ tickLower: -101, tickUpper: 100, tickSpacing: 10 }).ok, false);
  assert.equal(auditTicks({ tickLower: -887273, tickUpper: 100, tickSpacing: 1 }).ok, false);
});
test("recognizes ERC-721 mint from zero address", () => {
  const manager = "0x00000000000000000000000000000000000000f1";
  const log = {
    address: manager,
    topics: [
      id("Transfer(address,address,uint256)"),
      "0x" + ZeroAddress.slice(2).padStart(64, "0"),
      "0x" + "00000000000000000000000000000000000000a1".slice(2).padStart(64, "0"),
      "0x" + BigInt(42).toString(16).padStart(64, "0")
    ],
    data: "0x"
  };
  const parsed = classifyTransferLog(log, manager);
  assert.equal(parsed.isNftMint, true);
  assert.equal(parsed.tokenId, "42");
});
