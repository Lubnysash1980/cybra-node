# CYBRA Evolution Dashboard (isolated / read-only)

This package adds a local web dashboard and Termux CLI without changing the production CYBRA processes.

## What it measures

- **Evolution %** = (current tracked source/config/documentation bytes - baseline bytes) / baseline bytes × 100.
- The baseline is captured automatically on first run and stored at `$CYBRA_ROOT/state/evolution_dashboard/baseline.json`.
- A +3% crossing writes a timestamped JSON snapshot and a history event.
- Negative percentage means the tracked byte volume decreased. It is not automatically classified as a failure.
- Module count is a discovery count of files whose basename starts with `module_`, compared with the requested target of 500. This is not proof that every module is healthy or running.
- Auto-creation percentage is new tracked files divided by the current tracked file count.
- Health is deliberately shown as **not measured** until real per-module health checks are integrated. No fabricated health percentage is reported.

## Start in Termux

From the repository checkout:

```bash
cd ~/CYBRA
bash evolution_dashboard/cybra-evolution.sh start

# Короткий статус у Termux
bash evolution_dashboard/cybra-evolution.sh status

# Повний JSON
bash evolution_dashboard/cybra-evolution.sh json
```

Open `http://127.0.0.1:8765/` in the phone browser.

Commands:

```bash
bash evolution_dashboard/cybra-evolution.sh status
bash evolution_dashboard/cybra-evolution.sh logs
bash evolution_dashboard/cybra-evolution.sh stop
```

To monitor a different checkout:

```bash
CYBRA_ROOT="$HOME/CYBRA_NEURO" bash evolution_dashboard/cybra-evolution.sh start
```

## Safety

- The HTTP server binds only to `127.0.0.1`; it is not exposed to the public network.
- The dashboard does not execute code, alter files, create commits, or control PM2.
- **Automatic restart is MANUAL_ONLY.** A +3% event creates a snapshot and log entry only. Restart automation must not be enabled until a separate health gate, backup verification, restart target, and rollback procedure are implemented and tested.
- Baseline reset is intentionally not exposed in the web UI. To intentionally establish a new baseline, stop the server, back up the existing baseline, and remove `state/evolution_dashboard/baseline.json`; the next start will capture a new one.

## Limitations / next integration

The 500 indicators currently visualize discovered module files, not runtime health. The next safe integration step is to map the repository's authoritative module registry and real health-check outputs, then validate counts and statuses against CYBRA's existing manifest. Do not infer that the repository contains exactly 500 modules from this display.
