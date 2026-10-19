#!/data/data/com.termux/files/usr/bin/bash
CYBRA="$HOME/CYBRA"
BACKUP="$CYBRA/backup/evo_snapshot.tar.gz"
mkdir -p "$CYBRA/backup"
snapshot() { tar -czf "$BACKUP" -C "$CYBRA" evo bin data 2>/dev/null; echo "✅ Snapshot: $BACKUP"; }
restore() { [ -f "$BACKUP" ] || { echo "❌ Немає snapshot"; return 1; }; tar -xzf "$BACKUP" -C "$CYBRA" && echo "✅ Відновлено"; }
git_reset() { [ -d "$CYBRA/.git" ] || { echo "❌ Немає .git"; return 1; }; (cd "$CYBRA" && git reset --hard HEAD --quiet) && echo "✅ Git reset"; }
clean() {
    echo "⚠️  Відкат до чистої ноти EVO"
    read -r -p "Підтвердити? (yes/no): " ok
    [ "$ok" != "yes" ] && echo "скасовано" && return
    snapshot
    [ -d "$CYBRA/.git" ] && (cd "$CYBRA" && git reset --hard HEAD --quiet 2>/dev/null)
    echo "✅ Відкат виконано"
}
case "${1:-menu}" in
    snapshot) snapshot ;;
    restore) restore ;;
    git) git_reset ;;
    clean) clean ;;
    menu|*)
        while true; do
            echo ""
            echo "════ 152. ВІДКАТ EVO ════"
            echo "1) Snapshot  2) Відновити  3) Git reset  4) Відкат  0) Назад"
            read -r -p "Вибір: " c
            case "$c" in
                1) snapshot ;; 2) restore ;; 3) git_reset ;; 4) clean ;;
                0) exit 0 ;; *) echo "невідомо" ;;
            esac
        done ;;
esac
