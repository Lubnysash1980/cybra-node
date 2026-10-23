#!/data/data/com.termux/files/usr/bin/bash
# CYBRA Package Manager (Auto-install, Auto-remove, Cleanup)
CYBRA="$HOME/CYBRA"
LOG="$CYBRA/logs/pkg_manager.log"
mkdir -p "$CYBRA/logs"

log() { echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $1" >> "$LOG"; }
log "=== САНІТАРНА ПЕРЕВІРКА СИСТЕМИ ==="

# 1. ЖИТТЄВО НЕОБХІДНІ ПАКЕТИ (Ніколи не видаляються)
REQUIRED_PKGS=("sqlite" "nodejs" "python" "openssh" "git" "curl" "tar" "nano" "jq" "termux-api" "coreutils")

# 2. ПАКЕТИ-СМІТТЯ (Видаляються, якщо знайдені. Додавайте сюди те, що вам не потрібно)
JUNK_PKGS=("nmap" "metasploit" "ruby" "php" "postgresql" "mariadb") # Приклад

echo "⏳ 1. Оновлення списку пакетів..."
pkg update -y >/dev/null 2>&1 || log "Помилка pkg update"

echo "⏳ 2. Перевірка життєво необхідних пакетів..."
MISSING=()
for pkg in "${REQUIRED_PKGS[@]}"; do
    if ! command -v "$pkg" >/dev/null 2>&1 && ! dpkg -s "$pkg" >/dev/null 2>&1; then
        MISSING+=("$pkg")
    fi
done

if ! command -v pm2 >/dev/null 2>&1; then
    echo "⏳ Встановлення PM2..."
    npm install -g pm2 >/dev/null 2>&1
fi

if [ ${#MISSING[@]} -gt 0 ]; then
    echo "⏳ Встановлення відсутніх пакетів: ${MISSING[*]}"
    for pkg in "${MISSING[@]}"; do
        pkg install -y "$pkg" >/dev/null 2>&1 && log "Встановлено: $pkg"
    done
else
    echo "✅ Всі необхідні пакети на місці!"
fi

echo "⏳ 3. Видалення пакетів-сміття..."
REMOVED=0
for junk in "${JUNK_PKGS[@]}"; do
    if dpkg -s "$junk" >/dev/null 2>&1; then
        echo "🗑️ Видалення: $junk"
        pkg uninstall -y "$junk" >/dev/null 2>&1
        log "Видалено сміття: $junk"
        REMOVED=$((REMOVED+1))
    fi
done
[ "$REMOVED" -eq 0 ] && echo "✅ Сміття не знайдено."

echo "⏳ 4. Очищення сирітських залежностей (autoremove)..."
pkg autoremove -y >/dev/null 2>&1 || true

echo "⏳ 5. Очищення кешу (економія пам'яті)..."
pkg clean >/dev/null 2>&1 || true
npm cache clean --force >/dev/null 2>&1 || true
rm -rf ~/.cache/pip/* 2>/dev/null || true
log "Кеш очищено."

echo "⏳ 6. Оновлення пакетів (pkg upgrade)..."
pkg upgrade -y >/dev/null 2>&1 || log "Помилка pkg upgrade"

echo "✅ СИСТЕМА ПРОЙШЛА САНІТАРНУ ПЕРЕВІРКУ!"
log "=== ПЕРЕВІРКУ ЗАВЕРШЕНО ==="
