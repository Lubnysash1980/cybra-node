# CYBRA Control Plane: Termux Console + Server Runtime

## Deployment boundary

- **Termux is a client only.** It displays the dashboard and sends authenticated control requests.
- **The server is the only runtime host.** Module processes, module workers, the central controller/executor, health checks, evolution scoring, snapshots, and restarts run on the server.
- Do not start CYBRA workers, module processes, Redis, or the evolution engine from the Termux menu.
- The Termux menu must never write the server's state files directly.

## Components

1. **Server Control API** — authenticated HTTPS API; exposes health, summary, module status, history, and a small allowlist of control actions.
2. **Central Controller/Executor** — validates requests, serializes conflicting operations, checks preconditions, and coordinates workers.
3. **Module Supervisor** — tracks each registered module independently (status, heartbeat, health, restart count, last error).
4. **Module Neuro Worker** — one isolated worker per registered module; reports proposed evolution changes to the controller. A worker cannot restart itself or edit another module's state.
5. **Evolution Evaluator** — calculates positive/negative changes from measured metrics and a versioned baseline. It must not invent a score when metrics are missing.
6. **Snapshot Manager** — creates encrypted, timestamped snapshots on server storage outside the Git repository; verifies the snapshot before any restore.
7. **History/Audit** — append-only events for evolution, auto-creation, failures, snapshots, and restarts.

## Evolution and restart policy

- Show the evolution score as a measured delta against the previous accepted baseline; show the formula and sample count in the dashboard.
- A measured improvement of **+3.0 percentage points or more** requests a snapshot, validates it, then requests a controlled restart through the central executor.
- A negative delta marks the system **DEGRADED** and opens a review/diagnostic event. It does not automatically restore or restart.
- Missing, stale, or inconsistent metrics block automatic actions.
- Restart requests are idempotent, rate-limited, audited, and require a healthy verified snapshot. A restart is not triggered by a display calculation alone.

## Dashboard contract

The server returns a summary containing:
- registered_modules, online_modules, degraded_modules, failed_modules;
- health_percent, evolution_delta_percent, evolution_score;
- auto_created_count and auto_created_percent;
- positive_process_count and negative_process_count;
- restart_count, last_snapshot_at, last_restart_at;
- module-level status and timestamped daily history.

The dashboard's 0–100 progress bar is a visualization of the normalized evolution score. It is not the same value as the +3.0 percentage-point trigger.

Colors:
- green: healthy and fresh metrics;
- yellow: degraded/stale or awaiting review;
- red: failed, inconsistent, or unsafe to operate.

The UI must label unknown values as **N/A**, never as zero.

## Security and data placement

- No API tokens, private keys, passwords, live state, snapshots, or customer data in Git.
- Use two separate credentials: a Termux-to-API access token and a separate server-side signing/encryption key. Store them in environment variables or a secret manager, not in source files.
- Use HTTPS, token rotation, least privilege, request IDs, replay protection, and audit logging.
- Keep JSON state and snapshots on server-side persistent storage outside the repository. Git stores code, schemas, and documentation only.
- Backups must be encrypted and retained according to an explicit retention policy.

## Deployment sequence

1. Deploy the server API and controller in **read-only / observe-only** mode.
2. Register and inventory the real modules; do not assume there are 500 until the server inventory confirms the count.
3. Validate metrics, evolution calculations, history, and dashboard output.
4. Test snapshots and restore in an isolated staging environment.
5. Enable controlled restart actions only after health checks, authorization, and rollback tests pass.
6. Install the Termux dashboard client last; it only connects to the server API.

## Current implementation status

This document defines the target architecture. It does not claim that server processes are deployed, that 500 modules are online, or that automatic restarts are active. Those states must be confirmed by the server's live inventory and health API.
