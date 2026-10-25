#!/data/data/com.termux/files/usr/bin/bash
set -u
if [ $# -ge 1 ]; then TASK="$1"; else TASK=$(cat); fi
[ -z "$TASK" ] && { echo "ERR: no task"; exit 2; }
# ── Try AI Executor first ──
AI_EXEC="$HOME/CYBRA/modules/module_19_contract_tui_menu/bin/cybra_ai_executor.sh"
if [ -x "$AI_EXEC" ]; then
  MOD_N=$(echo "$TASK" | python3 -c "import sys,json;print(json.load(sys.stdin).get('module',0))" 2>/dev/null)
  MOD_NAME=$(echo "$TASK" | python3 -c "import sys,json;d=json.load(sys.stdin);p=d.get('path','');import os;print(os.path.basename(os.path.dirname(p)).replace(f'module_{{MOD_N}}_','').replace(f'module_{MOD_N}_','') or 'module')" 2>/dev/null)
  MOD_CAT=$(echo "$TASK" | python3 -c "import sys,json;d=json.load(sys.stdin);p=d.get('path','');import re;m=re.search(r'_([a-z]+)$',os.path.basename(os.path.dirname(p)));print(m.group(1) if m else 'custom')" 2>/dev/null)
  [ "$MOD_CAT" = "base" ] && MOD_CAT="custom"
  [ "$MOD_NAME" = "base" ] && MOD_NAME="module_$MOD_N"
  out=$(bash "$AI_EXEC" gen "$MOD_N" "$MOD_NAME" "$MOD_CAT" 2>&1)
  echo "$out"
  exit $?
fi
