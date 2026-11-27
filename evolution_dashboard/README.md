# CYBRA NEURO Evolution Dashboard

Local web panel and Termux CLI for evolution tracking. This component is isolated from production and does not change PM2 state.

## What the panel shows

- Evolution percentage = (current selected source/config/documentation bytes - baseline bytes) / baseline bytes × 100.
- The first run captures a baseline in `state/evolution_dashboard/baseline.json`. Initial files are not counted as newly created.
- When the measured byte volume crosses +3%, one timestamped JSON snapshot is written and a threshold event is added to the history.
- A negative percentage means byte volume decreased; it is not automatically a quality failure.
- Module count comes from the repository's authoritative `@cybra/index.json`. The current published registry has 83 entries, so the panel will show the actual count against the target of 500.
- Module dots: green = a real runtime health-check has passed; yellow = module exists but health is unknown; red = registry entry is missing on disk; grey = slot not yet registered. Until health checks are integrated, no module is falsely marked green.
- File-creation percentage means files added since baseline divided by the current scanned file count. It is a size/activity indicator, not proof of autonomous AI creation.
- Daily chart shows the last recorded evolution value and count of newly observed files for each day.
- Health percentage remains "not measured" until genuine health-check results are connected.

## Run in Termux

From the isolated checkout:

```bash
cd ~/CYBRA_NEURO
bash evolution_dashboard/cybra-evolution.sh start
bash evolution_dashboard/cybra-evolution.sh status
```

Open this address in the phone browser:

```
http://127.0.0.1:8765/
```

Other commands:

```bash
bash evolution_dashboard/cybra-evolution.sh json
bash evolution_dashboard/cybra-evolution.sh logs
bash evolution_dashboard/cybra-evolution.sh stop
bash evolution_dashboard/run-tests.sh
```

To explicitly monitor another checkout, set `CYBRA_ROOT` before running the script. Do not point it at production until the isolated panel has been reviewed.

## Safety boundary

- HTTP binds only to `127.0.0.1`; it is not exposed to the public network.
- The dashboard only reads project files and reads PM2 status with `pm2 jlist`; it never starts, stops, deletes, saves, or restarts PM2 processes.
- A +3% crossing automatically creates a JSON dump. Automatic restart remains `MANUAL_ONLY` until a real health gate, verified backup, explicit restart target, and tested rollback are implemented. The current registry has 83 modules and does not establish which production process is safe to restart.
- Negative byte growth is logged as a size decrease only; it does not trigger restart or rollback.
- Baseline reset is intentionally not exposed in the web UI. Back up the baseline before manually replacing it.

## Tests

Run:

```bash
bash evolution_dashboard/run-tests.sh
```

Tests use temporary directories and mock PM2. They do not touch production files or PM2 processes.
