# CYBRA contract registry

Static, read-only catalog interface.

## Current inventory

- Target: 500 catalog records.
- Total records: 177.
- Legacy menu actions recovered from the historical CYBRA TUI: 163. These are menu actions, not proof of deployed smart contracts.
- Solidity source files cataloged: 14.
- Confirmed on-chain deployments: 0 in this repository audit.
- Solidity test files found separately: 11. Test files are not counted as deployable contracts.

## Solidity source discovery

The repository tree contains 14 non-test Solidity source files:
- 4 under `modules/module_*/contracts/`: TimeLock, Anchor, Escrow, Reputation.
- 10 under `src/`: CYBRABinaryMixerLicense, CYBRADualLicenseRoyalty15, CYBRAEscrow, CYBRAExoskeletonAIParliament, CYBRALevelController, CYBRAP2PPurchase, CYBRARefundClaim, CYBRAResponsibilityContract, CYBRASelfLearning, CYBRASelfLearningV2.

The Parliament deployer module contains a discovery/compile/deploy workflow. Its presence is not evidence that those steps were executed successfully. The repository tree audit did not find a committed deployment registry or contract-address artifact that proves these contracts are live on a chain.

## Status rules

- `source-present-not-deployed`: Solidity source exists in this repository; deployment is not verified.
- `confirmed`: only use when there is independent on-chain evidence, including chain ID, contract address, and transaction hash.
- `proposed`: design idea or planned implementation; not existing contract code.
- `blocked`: implementation cannot currently be validated or used.

Never count menu actions, test files, interfaces, or unimplemented ideas as deployed contracts.

## Safety

- No wallet provider, wallet connection, message signing, transaction, deployment, or private-key handling in this UI.
- The catalog is informational and read-only.
- A source file is not a security audit, successful compilation, or deployment proof.

## Preview

Serve this directory as static files with any static HTTP server and open `index.html`.
