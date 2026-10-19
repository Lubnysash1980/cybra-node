#!/data/data/com.termux/files/usr/bin/bash
# 152: ВІДКАТ EVO — повний 100%
CYBRA="$HOME/CYBRA"
BACKUP="$CYBRA/backup/evo_snapshot.tar.gz"
LEVEL_FILE="$CYBRA/state/module_152.level"
LOG="$CYBRA/logs/module_152_rollback_evo.log"
mkdir -p "$CYBRA/backup" "$CYBRA/state" "$CYBRA/logs"
log() { echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $1" >> "$LOG"; }

level_now() { [ -f "$LEVEL_FILE" ] && cat "$LEVEL_FILE" || echo 1; }
level_set() { echo "$1" > "$LEVEL_FILE"; log "LEVEL: $1"; }
level1() { [ -d "$CYBRA" ] && return 0 || return 1; }
level2() { command -v tar >/dev/null && return 0 || return 1; }
level3() { [ -d "$CYBRA/evo" ] && return 0 || return 1; }
level4() { [ -d "$CYBRA/.git" ] && return 0 || return 1; }
level5() { [ -d "$CYBRA/sandbox" ] && return 0 || return 1; }
level6() { [ -d "$CYBRA/modules" ] && return 0 || return 1; }
level7() { [ -f "$BACKUP" ] || tar -czf "$BACKUP" -C "$CYBRA" evo bin data 2>/dev/null; return 0; }
run_levels() {
    local cur=$(level_now)
    for i in 1 2 3 4 5 6 7; do
        [ "$i" -lt "$cur" ] && continue
        if "level$i"; then level_set "$i"; else return 0; fi
    done
}

snapshot() { tar -czf "$BACKUP" -C "$CYBRA" evo bin data 2>/dev/null; echo "✅ Snapshot: $BACKUP"; log "SNAPSHOT"; }
restore() { [ -f "$BACKUP" ] || { echo "❌ Немає snapshot"; return 1; }; tar -xzf "$BACKUP" -C "$CYBRA" && echo "✅ Відновлено"; log "RESTORE"; }
git_reset() { [ -d "$CYBRA/.git" ] || { echo "❌ Немає .git"; return 1; }; (cd "$CYBRA" && git reset --hard HEAD --quiet) && echo "✅ Git reset"; log "GIT RESET"; }
clean() {
    echo "⚠️  Відкат до чистої ноти EVO"
    read -r -p "Підтвердити? (yes/no): " ok
    [ "$ok" != "yes" ] && echo "скасовано" && return
    snapshot
    [ -d "$CYBRA/.git" ] && (cd "$CYBRA" && git reset --hard HEAD --quiet 2>/dev/null)
    log "CLEAN"
    echo "✅ Відкат виконано"
}
progress() {
    echo "═══ ШЛЯХ ДО 100% ВІДКАТУ ═══"
    local pct=0
    [ -d "$CYBRA" ] && { echo "  [1] ✅ CYBRA"; pct=14; }
    command -v tar >/dev/null && { echo "  [2] ✅ tar"; pct=28; }
    [ -d "$CYBRA/evo" ] && { echo "  [3] ✅ EVO"; pct=42; }
    [ -d "$CYBRA/.git" ] && { echo "  [4] ✅ .git"; pct=56; }
    [ -d "$CYBRA/sandbox" ] && { echo "  [5] ✅ Sandbox"; pct=70; }
    [ -d "$CYBRA/modules" ] && { echo "  [6] ✅ Modules"; pct=84; }
    [ -f "$BACKUP" ] && { echo "  [7] ✅ Snapshot"; pct=100; }
    echo "Стан: $pct%"
}

run_levels
case "${1:-menu}" in
    snapshot) snapshot ;;
    restore) restore ;;
    git) git_reset ;;
    clean) clean ;;
    progress) progress ;;
    menu|*)
        while true; do
            echo ""
            echo "════ 152. ВІДКАТ EVO (рівень $(level_now)/7) ════"
            echo "1) Snapshot  2) Відновити  3) Git reset  4) Відкат  5) Прогрес  0) Назад"
            read -r -p "Вибір: " c
            case "$c" in
                1) snapshot ;; 2) restore ;; 3) git_reset ;; 4) clean ;;
                5) progress ;; 0) exit 0 ;; *) echo "невідомо" ;;
            esac
        done ;;
esac
