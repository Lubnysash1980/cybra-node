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
