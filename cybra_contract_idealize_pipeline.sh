#!/data/data/com.termux/files/usr/bin/bash
# CONTRACT IDEALIZE PIPELINE v2 — правильні шляхи + реальні критерії
set -u
source "$HOME/CYBRA/lib/parliament_api.sh"
CYBRA="$HOME/CYBRA"; cd "$CYBRA" || exit 1
LOG="$CYBRA/logs/contract_idealize.log"; mkdir -p "$CYBRA/logs"
log(){ echo "[$(date -u +%FT%TZ)] $*" | tee -a "$LOG"; }

TARGET="${1:-all}"
CONTRACTS_DIR="modules/module_19_contract_tui_menu/contracts"
LINKS_DIR="modules/module_19_contract_tui_menu/links"

log "═══ CONTRACT IDEALIZE v2: $TARGET ═══"
parliament_wait_ready 30 || { log "❌ parliament not ready"; exit 1; }

# ─── 1. Знайти контракти (правильний шлях) ───
CONTRACTS=()
if [ -d "$CONTRACTS_DIR" ]; then
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    CONTRACTS+=("$f")
  done < <(ls -1 "$CONTRACTS_DIR" 2>/dev/null | head -500)
fi

log "знайдено контрактів: ${#CONTRACTS[@]}"
log "знайдено лінків:    $(ls -1 "$LINKS_DIR" 2>/dev/null | wc -l)"

if [ ${#CONTRACTS[@]} -eq 0 ]; then
  log "❌ контрактів у $CONTRACTS_DIR немає"; exit 1
fi

# ─── 2. Подати задачу «ідеалізація» для кожного ───
LIMIT=500
[ "$TARGET" != "all" ] && LIMIT="$TARGET"
n=0
for cid in "${CONTRACTS[@]}"; do
  [ "$n" -ge "$LIMIT" ] && break
  # cid = ім'я файлу без розширення
  cname="${cid%.*}"
  parliament_submit "{
    \"id\":\"c_ideal_${cname}_$(date +%s)_${n}\",
    \"type\":\"contract_idealize\",
    \"contract_file\":\"$cid\",
    \"contract_id\":\"$cname\",
    \"dir\":\"$CONTRACTS_DIR\",
    \"links_dir\":\"$LINKS_DIR\",
    \"requirements\":[
      \"file_exists\",
      \"json_valid\",
      \"links_present\",
      \"license_1pct_1pct_1pct_ok\",
      \"pii_masked\",
      \"invoice_signed\",
      \"hash_valid\",
      \"metadata_complete\",
      \"bsc_chain_56_ok\"
    ]
  }" >/dev/null
  n=$((n+1))
done
log "подано задач: $n"
log "queue total: $(redis-cli llen cybra:parliament:queue)"

# ─── 3. Аудит кожного рівня окремо ───
for check in file json links license pii signature hash metadata bsc56; do
  parliament_submit "{
    \"id\":\"c_audit_${check}_$(date +%s)\",
    \"type\":\"contract_audit\",
    \"scope\":\"$check\",
    \"dir\":\"$CONTRACTS_DIR\"
  }" >/dev/null
done

# ─── 4. Чекати ───
log "→ чекаю обробки (до 10 хв)"
parliament_wait 600 0 || log "⚠ таймаут"

# ─── 5. Звіт ───
log "results total: $(redis-cli llen cybra:parliament:results)"
log "failed total:  $(redis-cli llen cybra:parliament:failed)"
log "level: $(parliament_level)/7"
