#!/data/data/com.termux/files/usr/bin/bash
# МОДУЛЬ 49: Executor list
# СТАТУС: BASE (готовий до апгрейду Парламентом)

CYBRA="$HOME/CYBRA"
LOG="$CYBRA/logs/module_49.log"
mkdir -p "$(dirname "$LOG")"
log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $1" >> "$LOG"; }

# ─── АВТО-ФІКС ПРИ ПОМИЛКАХ (EVO TRAP) ───
trap 'log "ERR line $LINENO"; echo "❌ Помилка в модулі 49. Лог: $LOG"; read -r _; exit 1' ERR

log "START: Executor list"
clear 2>/dev/null
echo "════════════════════════════════════════════"
echo "  [49] Executor list"
echo "════════════════════════════════════════════"

# ─── БАЗОВА ЛОГІКА ───
ls "$CYBRA/ai/evolution/suggestions/" 2>/dev/null

echo "════════════════════════════════════════════"
log "DONE: Executor list"

# ─── 7 РІВНІВ СКЛАДНОСТІ ───
LEVEL_FILE="/data/data/com.termux/files/home/CYBRA/state/main.sh.level"
level_now() { [ -f "$LEVEL_FILE" ] && cat "$LEVEL_FILE" || echo 1; }
level_set() { echo "$1" > "$LEVEL_FILE"; }
level1() { [ -d "$HOME/CYBRA" ] && return 0 || return 1; }
level2() { command -v bash >/dev/null && return 0 || return 1; }
level3() { [ -d "$HOME/CYBRA/modules" ] && return 0 || return 1; }
level4() { [ -d "$HOME/CYBRA/logs" ] && return 0 || return 1; }
level5() { [ -f "$HOME/CYBRA/evo/evo_core.py" ] && return 0 || return 1; }
level6() { [ -d "$HOME/CYBRA/modules" ] && return 0 || return 1; }
level7() { [ -d "$HOME/CYBRA/sandbox" ] && return 0 || return 1; }
run_levels() {
    local cur=$(level_now)
    for i in 1 2 3 4 5 6 7; do
        [ "$i" -lt "$cur" ] && continue
        if "level$i"; then level_set "$i"; else return 0; fi
    done
}
run_levels

read -r -p "Натисни Enter для виходу..." _
