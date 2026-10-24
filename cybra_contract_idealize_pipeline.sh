#!/data/data/com.termux/files/usr/bin/bash
# CONTRACT IDEALIZE PIPELINE — доопрацювання контрактів до ідеалу
# usage: ./cybra_contract_idealize_pipeline.sh [count|all]
set -u
source "$HOME/CYBRA/lib/parliament_api.sh"
CYBRA="$HOME/CYBRA"; cd "$CYBRA" || exit 1
LOG="$CYBRA/logs/contract_idealize.log"; mkdir -p "$CYBRA/logs"
log(){ echo "[$(date -u +%FT%TZ)] $*" | tee -a "$LOG"; }

TARGET="${1:-all}"
log "═══ CONTRACT IDEALIZE: $TARGET ═══"

parliament_wait_ready 30 || { log "❌ parliament not ready"; exit 1; }

# ─── 1. Знайти всі контракти ───
CONTRACTS=()
# з registry/
if [ -d registry ]; then
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    CONTRACTS+=("$(basename "$f" .json)")
  done < <(ls registry/*.json 2>/dev/null | head -200)
fi
# з redis
if [ ${#CONTRACTS[@]} -eq 0 ]; then
  while IFS= read -r c; do
    [ -z "$c" ] && continue
    CONTRACTS+=("$c")
  done < <(redis-cli smembers cybra:contracts 2>/dev/null | head -200)
fi
# з TUI-кешу (якщо є)
if [ ${#CONTRACTS[@]} -eq 0 ] && [ -d modules/module_19_contract_tui_menu/data ]; then
  while IFS= read -r c; do
    [ -z "$c" ] && continue
    CONTRACTS+=("$(basename "$c" .json)")
  done < <(ls modules/module_19_contract_tui_menu/data/*.json 2>/dev/null | head -200)
fi

log "знайдено контрактів: ${#CONTRACTS[@]}"

if [ ${#CONTRACTS[@]} -eq 0 ]; then
  log "⚠ контрактів не знайдено — створюю тестовий пакет"
  for i in 1 2 3 4 5; do
    parliament_submit "{
      \"id\":\"c_ideal_demo_$i\",
      \"type\":\"contract_idealize\",
      \"contract_id\":\"demo_$i\",
      \"requirements\":[\"validity\",\"links\",\"license\",\"pii\",\"signature\",\"hash\"]
    }" >/dev/null
  done
  log "queue: $(redis-cli llen cybra:parliament:queue)"
else
  # ─── 2. Подати задачу «ідеалізація» для кожного контракту ───
  LIMIT=200
  [ "$TARGET" != "all" ] && LIMIT="$TARGET"
  n=0
  for cid in "${CONTRACTS[@]}"; do
    [ "$n" -ge "$LIMIT" ] && break
    parliament_submit "{
      \"id\":\"c_ideal_${cid}_$(date +%s)\",
      \"type\":\"contract_idealize\",
      \"contract_id\":\"$cid\",
      \"requirements\":[
        \"all_links_verified\",
        \"license_1pct_1pct_1pct_ok\",
        \"pii_masked\",
        \"invoice_signed\",
        \"hash_valid\",
        \"metadata_complete\"
      ]
    }" >/dev/null
    n=$((n+1))
  done
  log "подано задач: $n"
fi

# ─── 3. Додатково — 5 аудитів на загальний стан ───
for check in validity links license pii signature; do
  parliament_submit "{
    \"id\":\"c_audit_${check}_$(date +%s)\",
    \"type\":\"contract_audit\",
    \"scope\":\"$check\"
  }" >/dev/null
done
log "queue total: $(redis-cli llen cybra:parliament:queue)"

# ─── 4. Чекати обробки ───
log "→ чекаю обробки (до 10 хв)"
parliament_wait 600 0 || log "⚠ таймаут"

# ─── 5. Звіт ───
log "results total: $(redis-cli llen cybra:parliament:results)"
log "failed total:  $(redis-cli llen cybra:parliament:failed)"
log "level: $(parliament_level)/7"

# ─── 6. Снапшот ───
./cybra_parliament_snapshot.sh "contract_ideal_$(date +%s)" 2>&1 | tail -3
