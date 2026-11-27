# Test-to-Live Promotion Workflow

Status: design specification; simulation only. This does not deploy or change production services.

## Required behavior

The TEST environment is used to develop and validate a candidate. Once the candidate has a verified 100% acceptance state, the system promotes that exact tested artifact to LIVE. TEST is then frozen and sealed at the promotion commit so that it cannot drift while LIVE is running. TEST can be resumed later as a separate development line.

## State machine

`TEST_ACTIVE -> TEST_VALIDATING -> TEST_SEALED -> LIVE_PREPARING -> LIVE_VERIFYING -> LIVE_ACTIVE`

If any promotion gate fails:

`TEST_VALIDATING -> TEST_ACTIVE`

If LIVE fails after activation:

`LIVE_ACTIVE -> LIVE_ROLLBACK -> LIVE_VERIFYING_PREVIOUS -> LIVE_ACTIVE_PREVIOUS`

If rollback cannot be verified, enter `SAFE_HALT` and alert an operator.

## Promotion gates (all required)

1. All required unit, integration, compatibility, and regression tests pass.
2. The test run is tied to an immutable commit SHA and recorded configuration.
3. The candidate's health, resource use, and error rate meet measured thresholds for a stable observation window.
4. Database/state migrations are backward-compatible or have a verified rollback.
5. A DUMP/checkpoint is created and independently verified.
6. The exact tested artifact is promoted; no rebuilding from a moving branch between test and live.
7. LIVE readiness checks pass before receiving production traffic/work.
8. The previous LIVE version remains available until post-promotion verification completes.

A displayed 100% is a summary only; it cannot override a failed hard gate.

## Freeze and resume rules

- On successful promotion, record the TEST branch, commit SHA, test report, configuration hash, and checkpoint ID in a promotion manifest.
- Mark that TEST snapshot SEALED/READ_ONLY. Do not continue writing new test changes into the sealed snapshot.
- LIVE runs from the promoted immutable commit.
- To resume testing, create or reopen a separate TEST working branch from the sealed snapshot (or a newer explicitly selected base). The LIVE branch is not silently merged into TEST.
- Changes made in resumed TEST must pass the complete gate sequence before another promotion.
- Auto-sync may fetch and compare remote changes, but must never auto-merge or auto-deploy to LIVE.

## Workflow ownership

- WORKER: proposes candidate and promotion plan.
- CONSTANT: enforces immutable safety and promotion rules.
- EXECUTOR: performs approved freeze, prepare, handover, and rollback actions.
- ADAPTIVE CONTROLLER: owns state transitions and prevents concurrent promotions.
- NEURO: evaluates health and evolution metrics.
- NOVU: coordinates bounded repair and recovery.
- DUMP: creates and verifies checkpoints.
- SYNC: fetches refs, checks divergence, verifies commit ancestry, and prepares a reviewable promotion manifest.

## Operational safeguards

- TEST and LIVE use separate configuration, secrets, process names, and state directories.
- No shared writable state unless an explicit concurrency-safe contract exists.
- Only one promotion lock may be held at a time; locks expire safely.
- All actions are idempotent and logged with a promotion ID.
- Failed checks stop promotion; no force push, destructive cleanup, or blind restart.
- LIVE promotion and any production deployment require explicit operator approval.
