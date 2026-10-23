#!/data/data/com.termux/files/usr/bin/bash
CYBRA="$HOME/CYBRA"
LOG="$CYBRA/logs/auto_pkg.log"
mkdir -p "$CYBRA/logs"

log() { echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $1" >> "$LOG"; }
log "=== ПЕРЕВІРКА СИСТЕМНИХ ПАКЕТІВ ==="

REQUIRED_PKGS=("sqlite" "nodejs" "python" "openssh" "git" "curl" "tar" "nano" "jq")
MISSING=()

for pkg in "${REQUIRED_PKGS[@]}"; do
    if ! command -v "$pkg" >/dev/null 2>&1 && ! dpkg -s "$pkg" >/dev/null 2>&1; then
        MISSING+=("$pkg")
        echo "❌ Відсутній пакет: $pkg"
    fi
done

if ! command -v pm2 >/dev/null 2>&1; then
    MISSING+=("pm2")
fi

if [ ${#MISSING[@]} -gt 0 ]; then
    echo "⏳ Встановлення відсутніх пакетів: ${MISSING[*]}"
    for pkg in "${MISSING[@]}"; do
        if [ "$pkg" == "pm2" ]; then
            npm install -g pm2 >/dev/null 2>&1 && echo "✅ Встановлено PM2"
        else
            pkg install -y "$pkg" >/dev/null 2>&1 && echo "✅ Встановлено $pkg"
        fi
    done
else
    echo "✅ Всі системні пакети на місці!"
fi

echo "⏳ Перевірка оновлень (pkg upgrade)..."
pkg upgrade -y >/dev/null 2>&1 || log "Помилка pkg upgrade"
echo "✅ Система готова до роботи!"
