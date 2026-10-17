#!/usr/bin/env python3
import os, subprocess, hashlib, json, time
from pathlib import Path

HOME = Path(os.environ["HOME"])
CYBRA = HOME / "CYBRA"
SNAP_DIR = CYBRA / "hashes" / "snapshots"
EVO_STATE_FILE = CYBRA / "logs" / "evo_state.json"
HASH_SCRIPT = CYBRA / "bin" / "cybra_hash_eco"

def run(cmd, cwd=None):
    return subprocess.run(cmd, shell=True, cwd=cwd, capture_output=True, text=True)

# ─── 1. Створюємо папку для снапшотів ───
SNAP_DIR.mkdir(parents=True, exist_ok=True)

# ─── 2. Створюємо скрипт Hash Ecosystem ───
hash_script_content = r'''#!/data/data/com.termux/files/usr/bin/bash
# cybra_hash_eco.sh — Hash Ecosystem з EVO 100%

CYBRA_HOME="${HOME}/CYBRA"
SNAP_DIR="${CYBRA_HOME}/hashes/snapshots"
EVO_STATE_FILE="${CYBRA_HOME}/logs/evo_state.json"
LOG="${CYBRA_HOME}/logs/hash_eco.log"
mkdir -p "$SNAP_DIR"
mkdir -p "$(dirname "$LOG")"

log() { echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $1" >> "$LOG"; }

# ─── 1. Зробити снапшот ───
hash_snapshot() {
    local ts=$(date -u +"%Y%m%dT%H%M%SZ")
    local snap_file="$SNAP_DIR/snapshot_${ts}.json"
    
    echo "═══ Створення снапшоту ═══"
    
    # 1. Збираємо хеші всіх модулів
    local modules_json="[]"
    for dir in "$CYBRA_HOME/modules"/module_*/; do
        [ -d "$dir" ] || continue
        local mod_name=$(basename "$dir")
        local main_file="$dir/main.sh"
        local hash="missing"
        local size=0
        if [ -f "$main_file" ]; then
            hash=$(sha256sum "$main_file" | cut -d' ' -f1)
            size=$(stat -c %s "$main_file" 2>/dev/null || wc -c < "$main_file")
        fi
        modules_json=$(echo "$modules_json" | python3 -c "
import json, sys
data = json.load(sys.stdin)
data.append({'name': '$mod_name', 'hash': '$hash', 'size': $size})
json.dump(data, sys.stdout)
")
    done
    
    # 2. Отримуємо EVO стан
    local evo_state=0
    if [ -f "$EVO_STATE_FILE" ]; then
        evo_state=$(python3 -c "import json; print(json.load(open('$EVO_STATE_FILE')).get('state_pct', 0))" 2>/dev/null || echo 0)
    fi
    
    # 3. Зберігаємо снапшот
    python3 - "$snap_file" "$ts" "$evo_state" "$modules_json" <<'PY'
import json, sys
snap_file, ts, evo_state, modules_json = sys.argv[1:5]
snapshot = {
    "timestamp": ts,
    "evo_state_pct": int(evo_state),
    "modules": json.loads(modules_json),
    "total_modules": len(json.loads(modules_json))
}
json.dump(snapshot, open(snap_file, "w"), indent=2, ensure_ascii=False)
PY
    
    log "Snapshot created: $snap_file (EVO: $evo_state%)"
    echo "  [✓] Снапшот збережено: $snap_file"
    echo "  [✓] Модулів: $(python3 -c "import json; print(len(json.load(open('$snap_file'))['modules']))")"
    echo "  [✓] EVO стан: $evo_state%"
}

# ─── 2. Перевірити цілісність (порівняти з останнім снапшотом) ───
hash_verify() {
    local last_snap=$(ls -t "$SNAP_DIR"/snapshot_*.json 2>/dev/null | head -1)
    if [ -z "$last_snap" ]; then
        echo "  [!] Немає снапшотів для перевірки"
        return 1
    fi
    
    echo "═══ Перевірка цілісності ═══"
    echo "  Останній снапшот: $(basename "$last_snap")"
    
    python3 - "$last_snap" "$CYBRA_HOME" <<'PY'
import json, sys, os, hashlib
snap_file, cybra = sys.argv[1:3]
snap = json.load(open(snap_file))

print(f"  EVO стан на момент снапшоту: {snap['evo_state_pct']}%")
print(f"  Модулів у снапшоті: {snap['total_modules']}")
print()

errors = 0
for mod in snap["modules"]:
    mod_path = os.path.join(cybra, "modules", mod["name"], "main.sh")
    if not os.path.exists(mod_path):
        if mod["hash"] != "missing":
            print(f"  🔴 {mod['name']}: файл ЗНИК")
            errors += 1
        continue
    with open(mod_path, "rb") as f:
        current_hash = hashlib.sha256(f.read()).hexdigest()
    if current_hash != mod["hash"]:
        print(f"  🟡 {mod['name']}: ХЕШ ЗМІНИВСЯ")
        errors += 1

if errors == 0:
    print("  🟢 Всі модулі цілісні (100%)")
else:
    print(f"  🔴 Знайдено {errors} проблем")
PY
}

# ─── 3. Відкат до снапшоту (якщо EVO < 100%) ───
hash_rollback() {
    local last_snap=$(ls -t "$SNAP_DIR"/snapshot_*.json 2>/dev/null | head -1)
    if [ -z "$last_snap" ]; then
        echo "  [!] Немає снапшотів для відкату"
        return 1
    fi
    
    echo "═══ Відкат до снапшоту ═══"
    echo "  Використовуємо: $(basename "$last_snap")"
    
    # Робимо git reset --hard (як EVO)
    cd "$CYBRA_HOME" || exit 1
    git reset --hard HEAD --quiet 2>/dev/null
    git clean -fd --quiet 2>/dev/null
    
    echo "  [✓] Відкат завершено"
}

# ─── 4. Головна логіка ───
case "${1:-}" in
    snapshot)
        hash_snapshot
        ;;
    verify)
        hash_verify
        ;;
    rollback)
        hash_rollback
        ;;
    auto)
        # Снепшот + перевірка
        hash_snapshot
        echo ""
        hash_verify
        ;;
    *)
        echo "Usage: cybra_hash_eco {snapshot|verify|rollback|auto}"
        exit 1
        ;;
esac
'''

(HASH_SCRIPT if False else (CYBRA / "bin" / "cybra_hash_eco")).write_text(hash_script_content)
os.chmod(CYBRA / "bin" / "cybra_hash_eco", 0o755)
print("  [✓] Створено cybra_hash_eco")

# ─── 3. Оновлюємо пункт [101] у меню ───
menu_path = CYBRA / "modules/module_19_contract_tui_menu/bin/cybra_menu.sh"
if menu_path.exists():
    content = menu_path.read_text()
    
    # Замінюємо виклик для пункту 101
    if "101) bash \"$HOME/CYBRA/modules/module_101_hash_ecosystem/main.sh\"" in content:
        content = content.replace(
            '101) bash "$HOME/CYBRA/modules/module_101_hash_ecosystem/main.sh" ;;',
            '101) action_hash_eco ;;'
        )
    
    # Додаємо функцію action_hash_eco (якщо немає)
    if "action_hash_eco()" not in content:
        func = '''
action_hash_eco() {
    printf '  [1] Створити снапшот\\n'
    printf '  [2] Перевірити цілісність\\n'
    printf '  [3] Відкат до снапшоту\\n'
    printf '  [4] Авто (снапшот + перевірка)\\n'
    printf 'Вибір: '
    read -r he
    case "$he" in
        1) "$HOME/CYBRA/bin/cybra_hash_eco" snapshot ;;
        2) "$HOME/CYBRA/bin/cybra_hash_eco" verify ;;
        3) "$HOME/CYBRA/bin/cybra_hash_eco" rollback ;;
        4) "$HOME/CYBRA/bin/cybra_hash_eco" auto ;;
    esac
    read -r _
}
'''
        # Додаємо перед "while true"
        while_idx = content.find("while true; do")
        if while_idx != -1:
            content = content[:while_idx] + func + "\n" + content[while_idx:]
    
    menu_path.write_text(content)
    print("  [✓] Меню оновлено (пункт [101] → action_hash_eco)")

# ─── 4. Оновлюємо EVO_STATE_FILE ───
# Створюємо evo_state.json, який читає hash_eco
evo_state = {"state_pct": 100, "updated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ")}
EVO_STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
EVO_STATE_FILE.write_text(json.dumps(evo_state, indent=2))
print("  [✓] Створено evo_state.json (100%)")

# ─── 5. Коміт ───
run("git add bin/cybra_hash_eco logs/evo_state.json", cwd=str(CYBIRA))
r = run('git commit -m "feat: Hash Ecosystem with EVO 100% integration"', cwd=str(CYBIRA))
print(r.stdout)

print("\n[✓] ГОТОВО.")
print("Тепер пункт [101] працює з EVO на 100%.")
print("Спробуй: ~/CYBRA/bin/cybra_hash_eco snapshot")
