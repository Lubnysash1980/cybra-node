#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MOD="$ROOT/modules/module_01_auto_executor"
STATE="$MOD/state/state.env"

mkdir -p "$MOD"/{state,evidence,snapshots}

cat > "$STATE" <<STATE
MODULE_ID=MODULE_01_AUTO_EXECUTOR
VERSION=1.0
MODE=TEST
STATUS=PENDING
PROJECT_READY=FALSE
PREFLIGHT=FALSE
LIVE_AUTHORIZATION=FALSE
TRUE_100=FALSE
RELEASE=BLOCKED
STATE_VERSION=1
STATE
