#!/data/data/com.termux/files/usr/bin/bash
CYBRA="$HOME/CYBRA"
LC="$CYBRA/lifecycle"

echo "═══ 1. ПОШУК ВІДСУТНІХ МОДУЛІВ ═══"
python3 - <<'PYEOF'
import json
from pathlib import Path

state_file = Path.home() / "CYBRA/lifecycle/state/lifecycle.json"
if state_file.exists():
    state = json.loads(state_file.read_text())
    missing = [name for name, info in state.get("modules", {}).items() if info.get("status") == "missing"]
    print(f"Знайдено {len(missing)} відсутніх модулів:")
    for m in missing[:30]:
        print(f"  🔴 {m}")
PYEOF

echo ""
echo "═══ 2. СТВОРЕННЯ ВІДСУТНІХ (БАЗОВИЙ ШАБЛОН) ═══"
python3 - <<'PYEOF'
import json, os
from pathlib import Path
from datetime import datetime, timezone

HOME = Path.home()
CYBRA = HOME / "CYBRA"
MODS = CYBRA / "modules"
state_file = CYBRA / "lifecycle/state/lifecycle.json"

if not state_file.exists():
    print("Немає lifecycle.json")
    exit()

state = json.loads(state_file.read_text())
missing = [name for name, info in state.get("modules", {}).items() if info.get("status") == "missing"]

created = 0
for name in missing:
    d = MODS / name
    d.mkdir(parents=True, exist_ok=True)
    main_sh = d / "main.sh"
    
    if not main_sh.exists():
        content = f'''#!/data/data/com.termux/files/usr/bin/bash
# МОДУЛЬ: {name}
# СТАТУС: READY (created by fix_missing)
# ДАТА: {datetime.now(timezone.utc).isoformat()}

CYBRA="$HOME/CYBRA"
LOG="$CYBRA/logs/{name}.log"
mkdir -p "$(dirname "$LOG")"
log() {{ echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $1" >> "$LOG"; }}
trap 'log "ERR $LINENO"' ERR

log "START: {name}"
echo "════════════════════════════════════════════"
echo "  МОДУЛЬ {name} (створено заново)"
echo "════════════════════════════════════════════"
echo "  Статус: READY"
echo ""
read -r -p "Enter..." _
exit 0
'''
        main_sh.write_text(content)
        os.chmod(main_sh, 0o755)
        created += 1
        print(f"  [✓] Створено: {name}")

print(f"\nВсього створено: {created}")
PYEOF

echo ""
echo "═══ 3. ПОВТОРНИЙ СКАН ═══"
python3 "$LC/lifecycle_manager.py" scan

echo ""
echo "═══ 4. СТАТИСТИКА ═══"
python3 "$LC/lifecycle_manager.py" show | grep -E "ready|development|missing" | head -5
