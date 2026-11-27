# Module 153 — PancakeSwap V3 read-only audit

This module is strictly READ-ONLY. It does not load wallets or .env files,
access seed phrases/private keys, sign messages, or submit transactions.
There is no approve/mint/swap/transfer implementation.

## Scope

- Read a transaction and receipt through public JSON-RPC.
- Distinguish not-found, pending/no-receipt, successful and failed receipts.
- Count ERC-20 Transfer events and decode ERC-721 Transfer events.
- Recognize an NFT mint only when Transfer originates from the zero address
  and, if supplied, the emitter matches the configured position manager.
- Test-safe helpers sort token metadata without detaching decimals and validate
  tick bounds against an explicitly verified tick spacing.

A successful receipt alone does not prove the intended pool position exists.
Verify the NFT contract, tokenId, ownerOf(tokenId), and positions(tokenId) using
separately reviewed read-only calls.

## Requirements

- Node.js 18+
- Existing ethers v6 package available to the project

No package manifest or dependency installation is changed by this module.

## Run

From repository root:

    node modules/module_153_pancakeswap_v3_audit/audit.mjs --help
    node modules/module_153_pancakeswap_v3_audit/audit.mjs --tx 0xa0ba7be3254cf5e7cca98363901f32f7b28866a6e2b86a8265a9c78ec04ffded

Optional arguments: --rpc URL and --position-manager ADDRESS.
Alternatively set BSC_RPC_URL or CYBRA_AUDIT_TX in the process environment.
The default RPC is a public BNB Smart Chain endpoint. Verify chainId 56.
No .env file is read. Never pass secrets as command-line arguments.

## Tests

    node --test modules/module_153_pancakeswap_v3_audit/tests/*.test.mjs

## Reported mint-log warnings

The supplied log values token0=0, token1=100e18, ticks [-439500,-437450],
and displayed price 11000000000000000000 are not enough to establish that
the intended price range was used. Before any future transaction workflow,
independently verify:

1. token address sorting and decimals after sorting;
2. whether price means token1 per token0 or its inverse;
3. human-unit to raw-unit conversion using both token decimals;
4. fee tier and tickSpacing against the deployed factory;
5. pool token0/token1, fee, slot0 and current tick;
6. both desired token amounts and resulting position amounts.

Do not infer fee spacing from an unchecked hard-coded lookup. Do not initialize
a pool at Q96 unless a 1:1 raw-unit price is explicitly intended and validated.

## Safety boundary

This is a diagnostic module, not an automated liquidity manager. It deliberately
contains no transaction-send path. Do not rerun the original production
auto-pool script while transaction status and token/tick calculations remain
unverified. A failed transaction can still consume network fees.
