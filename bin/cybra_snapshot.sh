#!/data/data/com.termux/files/usr/bin/bash
# CYBRA SNAPSHOT — мінімальний (код + configs, БЕЗ runtime/backups/tasks)
set -uo pipefail
CYBRA="$HOME/CYBRA"; cd "$CYBRA" || exit 1
TS=$(date +%Y%m%d_%H%M%S)
OUT="$CYBRA/snapshots/cybra_snapshot_$TS.tar.gz"
mkdir -p "$CYBRA/snapshots"

# Що включено (тільки необхідне для підняття системи)
INCLUDE=(
  bin/                    # всі скрипти
  controllers/            # 160 ctrl
  modules/                # 160+ модулів
  parliament_core/        # registry + priority_manager
  state/modules_spec.json
  state/hidl/hidl_schema.json
  state/evo_baseline.json
  lib/
  cybra                   # кореневий лаунчер
  cybra_goal.json
  parliament_executor_v6.py
  parliament_menu_worker.sh
  .gitignore
  README.md 2>/dev/null
)

echo "📦 snapshot → $OUT"
tar -czf "$OUT" \
  --exclude='modules/*/data/*' \
  --exclude='modules/*/backups/*' \
  --exclude='modules/*/bin/*.bak*' \
  --exclude='state/evo_*_backups' \
  --exclude='state/evo_backups' \
  --exclude='state/hidl_backups' \
  --exclude='state/module_backups' \
  --exclude='state/snapshots' \
  --exclude='state/executors' \
  --exclude='state/*.jsonl' \
  --exclude='logs/*' \
  --exclude='parliament_core/tasks/*.json' \
  --exclude='.git' \
  --exclude='node_modules' \
  --exclude='sandbox/*' \
  -C "$CYBRA" \
  bin controllers modules parliament_core lib state/hidl state/modules_spec.json \
  state/evo_baseline.json cybra cybra_goal.json parliament_executor_v6.py \
  parliament_menu_worker.sh .gitignore 2>/dev/null

SIZE=$(du -h "$OUT" | awk '{print $1}')
echo "✅ size: $SIZE"

# Git тег
if git rev-parse --git-dir >/dev/null 2>&1; then
  git add -A
  git commit -m "snapshot: $TS" 2>/dev/null || true
  TAG="snapshot-$TS"
  git tag -f "$TAG"
  git push origin main 2>&1 | tail -2
  git push origin "$TAG" -f 2>&1 | tail -2
  echo "✅ git: $TAG"
fi
