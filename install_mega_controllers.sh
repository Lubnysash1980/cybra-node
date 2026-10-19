#!/data/data/com.termux/files/usr/bin/bash
CYBRA="$HOME/CYBRA"
REG="$CYBRA/registry/controllers.json"
LOG="$CYBRA/logs/mega_controllers.log"
mkdir -p "$CYBRA/registry" "$CYBRA/logs" "$CYBRA/state"
log() { echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $1" >> "$LOG"; }

echo "═══ МЕГАСКРИПТ КОНТРОЛЕРІВ ═══"

L1() { [ -d "$CYBRA" ] || return 1; }
L2() { command -v sqlite3 >/dev/null || return 1; }
L3() { [ -f "$CYBRA/bin/cybra-controller" ] || return 1; }
L4() { [ -d "$CYBRA/registry" ] || return 1; }
L5() { [ -d "$CYBRA/sandbox" ] || mkdir -p "$CYBRA/sandbox"/{bin,tmp,keep,trash}; }
L6() { [ -f "$REG" ] || echo '{"controllers":{}}' > "$REG"; }
L7() { [ -d "$CYBRA/evo" ] || return 1; }
LEVELS=(L1 L2 L3 L4 L5 L6 L7)

find_real() {
    for f in "$CYBRA"/modules/*/main.sh "$CYBRA"/bin/*; do
        [ -f "$f" ] || continue
        grep -q "МОДУЛЬ.*(100%)" "$f" 2>/dev/null && continue
        grep -q "auto-resolved" "$f" 2>/dev/null && continue
        [ "$(stat -c%s "$f" 2>/dev/null || echo 0)" -gt 200 ] && echo "$f"
    done
}

real_scripts=($(find_real))
echo "Реальних скриптів: ${#real_scripts[@]}"

python3 - "$REG" "${real_scripts[@]}" <<'PYEOF'
import sys, json, os
from pathlib import Path
reg_path = Path(sys.argv[1])
scripts = sys.argv[2:]
d = {}
for s in scripts:
    key = os.path.basename(os.path.dirname(s)) + "_" + os.path.basename(s)
    key = key.replace("/", "_").replace(".", "_")
    d[key] = {"path": s, "levels": 7, "status": "active",
              "level_file": str(Path.home() / "CYBRA/state" / f"{key}.level")}
reg = {"controllers": d, "updated": __import__("datetime").datetime.utcnow().isoformat()+"Z"}
reg_path.write_text(json.dumps(reg, indent=2, ensure_ascii=False))
print(f"✅ Зареєстровано: {len(d)} контролерів")
PYEOF

echo ""
echo "─── 7 рівнів ───"
level=1
for fn in "${LEVELS[@]}"; do
    if $fn; then level=$((level+1)); echo "  [L$((level-1))] OK"
    else echo "  ⛔ L$level fail"; break; fi
done
echo "  Рівень: $((level-1))/7"

echo ""
echo "─── Тест ───"
for s in "${real_scripts[@]:0:5}"; do
    echo "  ▶ $(basename "$s")"
    "$CYBRA/bin/cybra-controller" "$s" 2>&1 | head -2
done
log "DONE: ${#real_scripts[@]} scripts, level $((level-1))/7"
echo ""
echo "✅ ГОТОВО: ${#real_scripts[@]} контролерів, рівень $((level-1))/7"
