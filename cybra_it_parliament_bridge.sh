#!/data/data/com.termux/files/usr/bin/bash
# Міст: IT-парламент генерує → Кіберпарламент виконує
set -u
source "$HOME/CYBRA/lib/parliament_api.sh"
CYBRA="$HOME/CYBRA"; cd "$CYBRA" || exit 1
LOG="$CYBRA/logs/it_bridge.log"; mkdir -p "$CYBRA/logs"
log(){ echo "[$(date -u +%FT%TZ)] $*" | tee -a "$LOG"; }

COUNT=${1:-20}
log "═══ IT → PARLIAMENT BRIDGE ($COUNT задач) ═══"

# 1. чекати готовності Кіберпарламенту
parliament_wait_ready 30 || { log "❌ parliament not ready"; exit 1; }

# 2. згенерувати завдання через IT-парламент
if [ -f cybra_it_evolution.py ]; then
  log "→ запускаю IT-генератор"
  timeout 30 python3 cybra_it_evolution.py --generate "$COUNT" >>"$LOG" 2>&1 || \
    log "⚠ IT-генератор завершився з помилкою"
fi

# 3. добрати до $COUNT, якщо IT не дав достатньо
q=$(redis-cli llen cybra:parliament:queue 2>/dev/null || echo 0)
if [ "$q" -lt "$COUNT" ]; then
  need=$((COUNT - q))
  log "→ добираю $need задач"
  for i in $(seq 1 "$need"); do
    parliament_submit "{\"id\":\"it_$(printf '%03d' $i)\",\"type\":\"it_evolution\",\"src\":\"it_bridge\",\"task\":\"evolve_module\"}" >/dev/null
  done
fi
log "queue: $(redis-cli llen cybra:parliament:queue)"

# 4. чекати виконання
log "→ чекаю обробки"
parliament_wait 300 0

# 5. звіт
log "results total: $(redis-cli llen cybra:parliament:results)"
log "failed total:  $(redis-cli llen cybra:parliament:failed)"
log "level: $(parliament_level)/7"
