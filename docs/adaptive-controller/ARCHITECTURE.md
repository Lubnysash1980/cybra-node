# CYBRA Adaptive Complexity Controller

Status: design scaffold; not connected to production processes.

## Goal

Keep one workload level active while maintaining the other six at a bounded standby level. A continuously running controller observes health and capacity, chooses a tested operating profile, and performs guarded handovers. The target is the highest **verified stable** operating level, not maximum CPU usage.

## Components

- **CONSTANT** — immutable safety limits, allowed transitions, resource ceilings, cooldowns, and rollback rules.
- **WORKER** — samples telemetry, detects trends, evaluates candidate profiles, and proposes a strategy.
- **EXECUTOR** — applies an approved strategy; it cannot override CONSTANT or controller safety gates.
- **ADAPTIVE CONTROLLER** — owns the state machine and is the only component allowed to change the active level.
- **NOVU** — recovery coordinator; diagnoses and requests bounded repair actions.
- **NEURO** — evaluates health/evolution metrics and validates a candidate profile.
- **PM2 adapter** — reports and controls managed process state; no direct shell execution from strategy data.
- **DUMP** — creates and verifies a recovery checkpoint before risky changes.

## Seven-level model

Exactly one level is ACTIVE. Other levels are STANDBY, WARMING, or DISABLED. Standby means lightweight readiness checks and bounded resource use, not seven full duplicate stacks.

A level is eligible for activation only when its configuration is valid, required dependencies are healthy, resource budget is available, and its test gate passes.

## State machine

`STABLE(n) -> PREPARE(n+1) -> VERIFY(n+1) -> HANDOVER(n+1) -> STABLE(n+1)`

On failure:

`ANY_ACTIVE -> ISOLATE -> ROLLBACK(last_known_good) -> VERIFY_ROLLBACK -> STABLE(previous)`

If rollback verification fails, enter `SAFE_HALT` and alert an operator. Never loop through levels indefinitely.

## Fast changes and noisy telemetry

- Use a fast sampling path for immediate overload/failure signals and a slower path for trend analysis.
- Apply hysteresis, minimum dwell time, cooldown, and a maximum transition rate to prevent flapping.
- A sudden spike may trigger protective throttling or rollback immediately; promotion still requires validation.
- If two processes are used for low-downtime handover, the incoming process must pass readiness checks before traffic/work is shifted. Resource budgets must account for temporary overlap.

## Meaning of 100%

Do not collapse all health into one percentage. Track at least:
- `health_score`: weighted operational health;
- `tests_passed`: passed / required tests;
- `readiness`: whether dependencies and rollback are ready;
- `capacity_headroom`: available capacity against configured limits.

Promotion requires all hard gates to pass. A displayed 100% is not permission to bypass safety gates.

## Safety invariants

1. CONSTANT limits cannot be changed by WORKER or EXECUTOR.
2. Only one controller instance may own transitions (lease/lock with expiry).
3. Every transition has an ID, reason, metrics snapshot, and audit record.
4. DUMP is verified before a risky change; an unverified dump is not a rollback point.
5. No automatic repair may run arbitrary commands or change secrets.
6. Failed health checks cause rollback or SAFE_HALT, not repeated blind restarts.
7. Production remains untouched until staging tests and an explicit deployment approval.

## Interfaces (proposed)

- `TelemetryProvider.sample()`
- `StrategyWorker.propose(snapshot, policy)`
- `Policy.validate(strategy, snapshot)`
- `Executor.prepare(strategy)`
- `Executor.activate(strategy)`
- `HealthVerifier.verify(level)`
- `RecoveryManager.rollback(checkpoint)`

All interfaces should return structured results with timeouts and typed errors. This document does not claim these interfaces already exist in the repository.
