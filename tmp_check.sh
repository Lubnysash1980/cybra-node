#!/data/data/com.termux/files/usr/bin/bash

# ─── BINMIX WRAP (65MB) ───
CYBRA_W="$HOME/CYBRA"
SANDBOX_W="$CYBRA_W/sandbox"
LIMIT_W=$((65 * 1024 * 1024))
mkdir -p "$SANDBOX_W"/{bin,tmp,keep,trash} 2>/dev/null
SIZE_W=$(du -sb "$SANDBOX_W" 2>/dev/null | awk "{print \$1}" || echo 0)
if [ "$SIZE_W" -ge "$LIMIT_W" ]; then
    rm -rf "$SANDBOX_W"/trash/* "$SANDBOX_W"/tmp/* 2>/dev/null
    [ -x "$SANDBOX_W/sandbox_cleanup.sh" ] && "$SANDBOX_W/sandbox_cleanup.sh" >/dev/null 2>&1
fi
BINMIX_W="$CYBRA_W/bin/cybra_binmix"
[ -x "$BINMIX_W" ] && "$BINMIX_W" status >/dev/null 2>&1
# ─── END BINMIX WRAP ───

# МОДУЛЬ 10: Підписати INVOICE
# СТАТУС: BASE (готовий до апгрейду Парламентом)

CYBRA="$HOME/CYBRA"
LOG="$CYBRA/logs/module_10.log"
mkdir -p "$(dirname "$LOG")"
log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $1" >> "$LOG"; }

# ─── АВТО-ФІКС ПРИ ПОМИЛКАХ (EVO TRAP) ───
trap 'log "ERR line $LINENO"; echo "❌ Помилка в модулі 10. Лог: $LOG"; read -r _; exit 1' ERR

log "START: Підписати INVOICE"
clear 2>/dev/null
echo "════════════════════════════════════════════"
echo "  [10] Підписати INVOICE"
echo "════════════════════════════════════════════"

# ─── БАЗОВА ЛОГІКА ───

read -p "Токен: " T; read -p "Wallet: " W; echo "$T|$W" >> "$CYBRA/logs/signs.log"; echo "✅"

echo "════════════════════════════════════════════"
log "DONE: Підписати INVOICE"

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
