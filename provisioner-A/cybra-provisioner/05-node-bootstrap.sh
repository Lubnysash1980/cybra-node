#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail
ROOT="${CYBRA_ROOT:-$HOME/CYBRA}"
SOURCE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
command -v node >/dev/null || { echo '[ERROR] Install nodejs first'; exit 1; }
command -v npm >/dev/null || exit 1
command -v pm2 >/dev/null || npm install -g pm2
mkdir -p "$ROOT" "$ROOT/state" "$ROOT/snapshots" "$ROOT/incidents"
for item in core cli config snapshot.manifest.json ecosystem.v3.config.js .env.example; do [ -e "$SOURCE/$item" ] && cp -a "$SOURCE/$item" "$ROOT/"; done
[ -f "$ROOT/.env" ] || cp "$ROOT/.env.example" "$ROOT/.env" 2>/dev/null || true
if [ -f "$ROOT/cli/package.json" ]; then (cd "$ROOT/cli" && npm link --force); fi
if [ -f "$ROOT/ecosystem.v3.config.js" ]; then pm2 start "$ROOT/ecosystem.v3.config.js" --update-env; pm2 save; fi
printf '[SUCCESS] Local isolated CYBRA node deployed at %s\n' "$ROOT"
command -v @cybra >/dev/null && @cybra status || true
