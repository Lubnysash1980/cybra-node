# CYBRA Neuro Binding

## Purpose
CYBRA Neuro is the task-aware coordinator for repository evolution. It binds user requests, contracts, modules, tests, workflows, and runtime observations to one canonical task ID in `ops/task-mapping/tasks.json`.

## Lifecycle
1. Intake: accept a user request, GitHub issue, contract source, or module reference.
2. Normalize: create or find one task ID; avoid duplicate tasks for the same requested outcome.
3. Map: identify affected modules, dependencies, executors, risks, and acceptance criteria.
4. Plan: split complex work into bounded subtasks, all linked to the parent task.
5. Execute: prepare changes in an isolated feature branch or workspace; never overwrite the primary branch directly.
6. Verify: run syntax checks, unit tests, contract compilation/tests, and relevant workflow checks.
7. Review: publish changed-file list, diff summary, test evidence, unresolved risks, and proposed next step.
8. Learn: record verified fixes and regressions in the task event history and update the module map.

## Adaptive work granularity (progressive fallback)
Neuro must not abandon a task merely because a large operation fails. It should reduce scope and retry safely:
1. GB-scale: whole repository/module or large artifact batches.
2. MB-scale: individual packages, modules, or bounded file groups.
3. KB-scale: individual files, functions, or small patches.
4. Byte-scale: exact byte ranges or minimal textual edits, preserving encoding and newlines.
5. Bit-scale: binary-level inspection/patching only when the format is understood and a deterministic validator exists.
6. Pixel-scale: image assets only, such as bounded image-region/pixel-grid edits. Pixels are not a meaningful source-code unit; for code use token/line/byte-level patches.
At every reduction, save a checkpoint, record the failed scope and reason, validate the smaller change, and keep a rollback path. Never promise guaranteed success: if safe attempts fail, report the blocker and evidence rather than corrupting files or looping forever.

## Build, test, repair, and run pipeline
Inspect actual manifests and available scripts before choosing commands. When applicable:
1. Detect package manager and lockfile; use reproducible install (`npm ci` when a valid npm lockfile exists), not arbitrary global upgrades.
2. Inspect package scripts and run available lint, typecheck, unit/integration tests, build, and Solidity compile/test commands.
3. Capture exit codes, bounded logs, tool versions, changed files, and artifact hashes.
4. On failure, classify the error, make the smallest isolated repair, then rerun the failed check and relevant regression tests.
5. Run bounded smoke tests only in safe local/test environments. Production run/deploy/restart requires explicit approval.
6. Never silently delete dependencies, rewrite lockfiles, or perform destructive cleanup. Preserve diffs and rollback checkpoints.

## Script generation and commit evidence
- Neuro may generate helper scripts and tests in the task branch; each script documents purpose, inputs, outputs, safety boundaries, and usage.
- Validate scripts with the relevant syntax checker and dry-run/test mode before suggesting execution.
- Each task should produce a Git commit containing reviewed changes, with the task ID in the commit message where practical.
- Record commit SHA, branch, changed paths, executor, timestamp, and associated test/workflow run IDs as evidence on the same task.
- A commit proves that a versioned change was recorded; it does not alone prove that the script ran correctly. Functional completion requires passing tests or a documented runtime smoke test.
## Executor model
- `neuro`: decomposition, repository analysis, patch proposals, test planning, result synthesis.
- `github-actions`: repeatable CI, scheduled checks, validation and build/test jobs.
- `oracle-vps`: runtime health and deployment target, only after credentials and connectivity are configured.
- `termux`: operator-side diagnostics and optional local dashboard; not required for Oracle uptime.

Multiple executors may work on one task, but they must share the same task ID and report separate events/evidence. A coordinator owns integration and conflict resolution. Executors must not independently create competing implementations for the same acceptance criteria.

## Autonomy and permissions
- Read repository files and map dependencies by default.
- Generate plans, patches, tests, and isolated branches within granted repository permissions.
- Require human approval before merging to protected branches, deploying, restarting production services, changing secrets/permissions, or performing irreversible operations.
- Never request or store private keys, wallet seed phrases, passwords, or raw access tokens in task files or logs.
- Smart-contract work defaults to static analysis, compilation, and tests. No wallet signing, token transfer, or on-chain deployment without a separate explicit approval flow.

## Reliability rules
- Idempotent task creation and updates; stable task IDs.
- Every status transition writes an append-only event with executor, timestamp, and evidence.
- Green requires 100%, completed acceptance criteria, and verifiable evidence.
- Yellow means 30-99% or a measured degradation at/above 30%.
- Red means below 30% for an active/measured task, or a confirmed failed/blocked state.
- Not checked is distinct from failure.
- Use bounded retries, exponential backoff, timeouts, and a circuit breaker; no infinite self-restart loops.
- Run dependency changes in an isolated workspace; preserve lockfiles and show diffs. No automatic destructive npm cleanup.
- On conflicting edits, stop integration, preserve both results, and ask the coordinator to reconcile.

## Current implementation status
The repository currently contains an executor registry entry for `neuro` and a shared task map. This document defines the integration contract; it does not claim that a live autonomous agent, chat service, GitHub OAuth app, or VPS runtime is already connected.

## Acceptance criteria for activation
1. A request can be converted into one mapped task without duplication.
2. The task is linked to relevant repository paths and executors.
3. Neuro can prepare an isolated patch and tests.
4. CI reports verifiable results back to the same task ID.
5. The dashboard shows task state, executor activity, evidence, and approval gates.
6. A human can approve or reject merge/deploy actions.
7. Integration tests prove that retries, conflicts, and failed executors do not corrupt the task map.
8. Adaptive fallback narrows failed operations while preserving rollback capability.
9. Applicable build/compile/test checks capture exit codes and logs.
10. Generated scripts are syntax-checked and dry-run tested.
11. Commit SHA and CI evidence attach to the same task; commit-only evidence is not runtime proof.
