#!/data/data/com.termux/files/usr/bin/bash
# 160 пунктів меню TUI → Кіберпарламент → обробка → звіт
# usage: ./cybra_menu_160_to_ideal.sh [N|all]
set -u
source "$HOME/CYBRA/lib/parliament_api.sh"
CYBRA="$HOME/CYBRA"; cd "$CYBRA" || exit 1
LOG="$CYBRA/logs/menu_160_ideal.log"; mkdir -p "$CYBRA/logs"
log(){ echo "[$(date -u +%FT%TZ)] $*" | tee -a "$LOG"; }

TARGET=${1:-160}
CONTRACTS_DIR="modules/module_19_contract_tui_menu/contracts"
LINKS_DIR="modules/module_19_contract_tui_menu/links"
CONTROLLERS="registry/controllers.json"

log "═══ MENU 160 → IDEAL (target=$TARGET) ═══"
parliament_wait_ready 30 || { log "❌ parliament not ready"; exit 1; }

# ─── Збираємо реальні ID ───
mapfile -t CONTRACTS < <(ls -1 "$CONTRACTS_DIR" 2>/dev/null | sed 's/\.[^.]*$//')
mapfile -t LINKS < <(ls -1 "$LINKS_DIR" 2>/dev/null | sed 's/\.[^.]*$//')
N_C=${#CONTRACTS[@]}
N_L=${#LINKS[@]}
log "контрактів=$N_C, лінків=$N_L, controllers=$([ -f $CONTROLLERS ] && echo yes || echo no)"

SUBMITTED=0
submit(){
  local type="$1" action="$2" cid="${3:-}" extra="${4:-{}}"
  parliament_submit "{
    \"id\":\"menu160_$(printf '%03d' $((SUBMITTED+1)))_$(date +%s)\",
    \"type\":\"$type\",
    \"action\":\"$action\",
    \"contract_id\":\"$cid\",
    \"requirements\":[\"logic_correct\",\"data_consistent\",\"pii_masked\",\"license_1pct_1pct_1pct\",\"bsc56\",\"hash_valid\"],
    \"extra\":$extra
  }" >/dev/null
  SUBMITTED=$((SUBMITTED+1))
  [ "$SUBMITTED" -ge "$TARGET" ] && return 1
  return 0
}

# ═══ A. Створення/список/статус (20) ═══
log "A. Створення/список/статус (20)"
for i in $(seq 0 19); do
  cid="${CONTRACTS[$i]:-demo_$i}"
  case $((i % 3)) in
    0) submit "menu_action" "create_contract" "$cid" '{"check":"idempotent"}' ;;
    1) submit "menu_action" "list_contracts"   ""    '{"check":"no_missing"}' ;;
    2) submit "menu_action" "show_status"      "$cid" '{"check":"status_valid"}' ;;
  esac
  [ "$SUBMITTED" -ge "$TARGET" ] && break
done

# ═══ B. Лінки (25) ═══
log "B. Лінки (25)"
for i in $(seq 0 24); do
  lid="${LINKS[$i]:-link_$i}"
  case $((i % 2)) in
    0) submit "menu_action" "generate_links" "$lid" '{"check":"targets_exist"}' ;;
    1) submit "menu_action" "confirm_link"   "$lid" '{"check":"signed_valid"}' ;;
  esac
  [ "$SUBMITTED" -ge "$TARGET" ] && break
done

# ═══ C. Ліцензії (15) ═══
log "C. Ліцензії (15)"
for i in $(seq 0 14); do
  case $((i % 2)) in
    0) submit "menu_action" "dual_license_ledger" "" '{"check":"sum_3pct"}' ;;
    1) submit "menu_action" "creation_license"    "" '{"check":"1pct_marked"}' ;;
  esac
  [ "$SUBMITTED" -ge "$TARGET" ] && break
done

# ═══ D. INVOICE (20) ═══
log "D. INVOICE (20)"
for i in $(seq 0 19); do
  cid="${CONTRACTS[$((i % N_C))]:-inv_$i}"
  case $((i % 4)) in
    0) submit "menu_action" "create_invoice"   "$cid" '{"check":"number_unique"}' ;;
    1) submit "menu_action" "add_line"         "$cid" '{"check":"amount_positive"}' ;;
    2) submit "menu_action" "show_invoice"     "$cid" '{"check":"matches_ledger"}' ;;
    3) submit "menu_action" "finalize_invoice" "$cid" '{"check":"signed_and_sealed"}' ;;
  esac
  [ "$SUBMITTED" -ge "$TARGET" ] && break
done

# ═══ E. PII (15) ═══
log "E. PII (15)"
for i in $(seq 0 14); do
  case $((i % 3)) in
    0) submit "menu_action" "export_masked"     "" '{"check":"no_plain_pii"}' ;;
    1) submit "menu_action" "export_all_masked" "" '{"check":"count_matches"}' ;;
    2) submit "menu_action" "verify_pii"        "" '{"check":"hash_matches"}' ;;
  esac
  [ "$SUBMITTED" -ge "$TARGET" ] && break
done

# ═══ F. Hardening/Debug (15) ═══
log "F. Hardening/Debug (15)"
for i in $(seq 0 14); do
  case $((i % 3)) in
    0) submit "menu_action" "hardening"   "" '{"check":"all_locks_present"}' ;;
    1) submit "menu_action" "debug"       "" '{"check":"no_errors"}' ;;
    2) submit "menu_action" "dual_verify" "" '{"check":"two_independent"}' ;;
  esac
  [ "$SUBMITTED" -ge "$TARGET" ] && break
done

# ═══ G. AI-асистент (20) ═══
log "G. AI-асистент (20)"
AI_ACTIONS=(ai_review ai_parse ai_terms ai_help ai_ask ai_taskbar ai_exec_full ai_exec_scan ai_exec_apply ai_exec_list)
for i in $(seq 0 19); do
  act="${AI_ACTIONS[$((i % ${#AI_ACTIONS[@]}))]}"
  submit "menu_action" "$act" "" '{"check":"returned_valid"}' || break
done

# ═══ H. Address book / контролери (15) ═══
log "H. Address book / контролери (15)"
for i in $(seq 0 14); do
  case $((i % 3)) in
    0) submit "menu_action" "addr_add"     "" '{"check":"no_duplicates"}' ;;
    1) submit "menu_action" "addr_list"    "" '{"check":"count_ok"}' ;;
    2) submit "menu_action" "addr_history" "" '{"check":"chronological"}' ;;
  esac
  [ "$SUBMITTED" -ge "$TARGET" ] && break
done

# ═══ I. Preflight/Heal (15) ═══
log "I. Preflight/Heal (15)"
LAST_ACTIONS=(preflight self_heal ownership check_timeouts refund_status add_term show_rates update_rate convert buyer_final_decision)
for i in $(seq 0 14); do
  act="${LAST_ACTIONS[$((i % ${#LAST_ACTIONS[@]}))]}"
  submit "menu_action" "$act" "" '{"check":"exit_zero"}' || break
done

# ═══ Добити до рівно $TARGET, якщо чогось не хватило ═══
while [ "$SUBMITTED" -lt "$TARGET" ]; do
  submit "menu_action" "idealize_sweep" "" '{"check":"idempotent"}' || break
done

log "✅ подано рівно: $SUBMITTED"
log "queue: $(redis-cli llen cybra:parliament:queue)"

# ─── Чекати обробки ───
log "→ чекаю обробки (до 15 хв)"
BEFORE=$(redis-cli llen cybra:parliament:results 2>/dev/null || echo 0)
parliament_wait 900 0 || log "⚠ таймаут"
AFTER=$(redis-cli llen cybra:parliament:results 2>/dev/null || echo 0)
log "results: $BEFORE → $AFTER (+$((AFTER-BEFORE)))"
log "failed:  $(redis-cli llen cybra:parliament:failed)"
log "level:   $(parliament_level)/7"

# ─── Фінальний снапшот ───
./cybra_parliament_snapshot.sh "menu160_ideal_$(date +%s)" 2>&1 | tail -3
