# CYBRA Autonomous Selection and Component Neuro Policy

Status: implementation plan based on the current repository audit. No production behavior is changed by this document.

## Objective

CYBRA should automatically select the best *verified* operating strategy from candidates tested in TEST. It must not select by a single percentage, guess from missing telemetry, or deploy an unverified candidate.

## Existing components found in this branch

The repository already contains:
- `module_500_neuro/neuro.py`: staged code-generation and guarded-apply workflow.
- `module_320_controllers/controllers.py`: centralized checks for system controllers and integrity.
- `module_350_controller_worker/worker.py`: metric snapshots, baseline deviation checks, controller/health/completion checks and healing loop.
- `module_360_mapping/mapping.py`: module-to-controller, priority, dependency and healing-action map.
- `module_380_sic/sic.py`: module registry, event bus, conflict coordination, orchestration and system snapshots.
- `module_399_gate/gate.py`: action gate based on health/controller/completion state.
- `module_121_parlament/sync.py`: Git synchronization and merge operations.
- `bin/cybra_auto_backup.sh`: local timestamped archive and checksum with local rotation.

These are existing code components, not proof that every component already has its own running NEURO instance. Component-level NEURO adapters and the dedicated NOVU recovery role must be verified/implemented against the real module interfaces.

## Required hierarchy

Each registered component receives a local supervision contract:
1. Component adapter reports health, version, dependencies, resource use, error rate, and last successful check.
2. Local NEURO evaluates telemetry and proposes a bounded repair or optimization.
3. Local controller validates the proposal against immutable policy and component-specific limits.
4. SIC coordinates cross-component dependencies and conflicts.
5. Central ADAPTIVE CONTROLLER owns global state transitions and TEST/LIVE promotion.
6. An independent recovery supervisor handles controller failure and restores a known-good snapshot; it must not depend on the failed controller.

Parliament remains governance/approval and audit. Worker evaluates candidate strategies. Executor applies only a validated and authorized candidate. DUMP provides recovery points. SYNC fetches and compares versions; it must not silently merge or deploy LIVE.

## Automatic candidate selection

Selection is a two-stage process.

### Stage A — hard eligibility gates

Reject a candidate if any condition is true:
- required tests failed, are missing, or were not run against the exact candidate commit;
- source commit or artifact hash is unknown or changed after testing;
- a required component has missing/stale telemetry;
- controller, integrity, signature, dependency, or security checks fail;
- the candidate exceeds CPU, RAM, disk, network, or standby resource ceilings;
- fewer than five verified recovery points exist for the relevant environment;
- the rollback snapshot or restore test is unavailable;
- the candidate changes protected configuration, secrets, or LIVE state;
- required approval is absent.

A candidate that fails a hard gate is ineligible regardless of its score.

### Stage B — compare eligible candidates

Compare only eligible candidates over the same stable observation window. Use measured values for:
- reliability and error rate;
- health and regression-test results;
- latency and throughput where relevant;
- resource consumption and remaining headroom;
- recovery time and rollback success;
- dependency impact and operational complexity.

Normalize metrics against declared limits and baseline. Prefer the candidate that meets all hard requirements with the best measured reliability/resource balance. Record the raw metrics, scoring policy version, candidate commit SHA, and reason for selection. If candidates are statistically indistinguishable, prefer the current known-good candidate; do not churn.

The scoring weights must be calibrated from real TEST measurements, not invented before baseline collection. A score never overrides a failed hard gate.

## TEST-to-LIVE state machine

DISCOVER -> BASELINE -> GENERATE_CANDIDATES -> TEST -> VALIDATE -> COMPARE -> SELECT -> SEAL

After sealing, the exact immutable artifact may enter MERGE_PREPARATION. Merge and LIVE deployment remain separate approval-gated operations. After deployment, run post-deploy health checks and retain the previous LIVE snapshot for rollback.

Any failure returns to the previous stable TEST candidate or enters SAFE_HALT if recovery cannot be verified.

## Recovery and DUMP requirements

Maintain at least five distinct verified recovery points for TEST and five for LIVE. Keep copies across independent failure domains. A backup is not verified merely because a tar command or checksum command returned output: test archive readability, checksum, manifest, and isolated restore.

A new dump must never overwrite an existing verified recovery point. A failed backup must not trigger retention cleanup. Recovery tries candidates newest-to-oldest only after checksum and compatibility checks; every restore is first performed in an isolated location.

## Current audit blockers before LIVE automation

1. `bin/cybra_auto_backup.sh` currently writes local archives and rotates them locally. It does not establish independent secondary/off-site copies or perform a restore test. It does not yet meet the five verified recovery-point policy.
2. `module_121_parlament/sync.py` currently has automatic pull/merge behavior. Its `_gate_ok` path returns an allow result when the gate cannot be imported. This is fail-open and must be changed to fail-closed before privileged sync/merge actions can be trusted.
3. `module_399_gate/gate.py` currently allows unknown actions by default and has overlapping allow/block action names. The action policy needs an explicit allowlist and deny-by-default behavior before it can guard LIVE operations.
4. `module_350_controller_worker/worker.py` contains an automatic healing loop. Its repair actions and process-start behavior must be constrained by a TEST-only executor and verified rollback before any production use.
5. The current tree shows NEURO and SIC components, but a dedicated NOVU module and a distinct independent recovery supervisor have not yet been confirmed by this audit.

## Implementation order

1. Inventory module interfaces, dependencies, process definitions, tests, and current backups. Read-only only.
2. Build isolated test harness and telemetry contract for each component.
3. Add component-level NEURO/controller adapters using existing modules where suitable.
4. Harden Gate and SYNC to deny by default; fetch/compare must be separate from merge/deploy.
5. Implement verified five-point DUMP rotation and isolated restore tests.
6. Implement candidate evaluator and deterministic selection in TEST.
7. Add independent recovery supervisor and fault-injection tests.
8. Enable TEST automation only after tests pass. Consider LIVE integration only after explicit review and approval.

## Safety boundary

This branch is not connected to the live server by this document. Do not change main, frozen contracts, production PM2, Termux state, secrets, or LIVE data during implementation. Never claim automatic selection, backup protection, or recovery is active until code is installed and the corresponding tests and restore drills have succeeded.
