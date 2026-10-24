#!/data/data/com.termux/files/usr/bin/bash
# 160 пунктів меню TUI → окрема черга cybra:menu:queue → menu-worker
set -u
CYBRA="$HOME/CYBRA"; cd "$CYBRA" || exit 1
LOG="$CYBRA/logs/menu_160_ideal.log"; mkdir -p "$CYBRA/logs"
log(){ echo "[$(date -u +%FT%TZ)] $*" | tee -a "$LOG"; }
rd(){ redis-cli "$@" 2>/dev/null; }

TARGET=${1:-160}
CONTRACTS_DIR="modules/module_19_contract_tui_menu/contracts"
LINKS_DIR="modules/module_19_contract_tui_menu/links"

log "═══ MENU 160 → IDEAL (target=$TARGET) ═══"
rd ping | grep -q PONG || { log "❌ redis down"; exit 1; }

mapfile -t CONTRACTS < <(ls -1 "$CONTRACTS_DIR" 2>/dev/null | sed 's/\.[^.]*$//')
mapfile -t LINKS < <(ls -1 "$LINKS_DIR" 2>/dev/null | sed 's/\.[^.]*$//')
N_C=${#CONTRACTS[@]}; N_L=${#LINKS[@]}
log "контрактів=$N_C, лінків=$N_L"

SUBMITTED=0
submit(){
  local action="$1" cid="${2:-}" check="${3:-ok}"
  local id="menu160_$(printf '%03d' $((SUBMITTED+1)))_$(date +%s)"
  # компактний JSON — одним рядком, без пробілів
  local task
  task=$(python3 -c "import json,sys;print(json.dumps({'id':sys.argv[1],'type':'menu_action','action':sys.argv[2],'contract_id':sys.argv[3] or '','check':sys.argv[4],'ts':int(__import__('time').time())},separators=(',',':')))" \
    "$id" "$action" "$cid" "$check")
  printf '%s' "$task" | rd -x rpush cybra:menu:queue >/dev/null
  SUBMITTED=$((SUBMITTED+1))
  [ "$SUBMITTED" -ge "$TARGET" ] && return 1
  return 0
}

# ─── A. Створення/список/статус (20) ───
log "A. контракти (20)"
for i in $(seq 0 19); do
  cid="${CONTRACTS[$i]:-demo_$i}"
  case $((i % 3)) in
    0) submit "create_contract" "$cid" "idempotent" || break ;;
    1) submit "list_contracts"  ""     "no_missing" || break ;;
    2) submit "show_status"     "$cid" "status_valid" || break ;;
  esac
  done

# ─── B. Лінки (25) ───
log "B. лінки (25)"
for i in $(seq 0 24); do
  lid="${LINKS[$i]:-link_$i}"
  case $((i % 2)) in
    0) submit "generate_links" "$lid" "targets_exist" || break ;;
    1) submit "confirm_link"   "$lid" "signed_valid" || break ;;
  esac
  done

# ─── C. Ліцензії (15) ───
log "C. ліцензії (15)"
for i in $(seq 0 14); do
  case $((i % 2)) in
    0) submit "dual_license_ledger" "" "sum_3pct" || break ;;
    1) submit "creation_license"    "" "1pct_marked" || break ;;
  esac
  done

# ─── D. INVOICE (20) ───
log "D. INVOICE (20)"
for i in $(seq 0 19); do
  cid="${CONTRACTS[$((i % (N_C>0?N_C:1)))]:-inv_$i}"
  case $((i % 4)) in
    0) submit "create_invoice"   "$cid" "number_unique" || break ;;
    1) submit "add_line"         "$cid" "amount_positive" || break ;;
    2) submit "show_invoice"     "$cid" "matches_ledger" || break ;;
    3) submit "finalize_invoice" "$cid" "signed_and_sealed" || break ;;
  esac
  done

# ─── E. PII (15) ───
log "E. PII (15)"
for i in $(seq 0 14); do
  case $((i % 3)) in
    0) submit "export_masked"     "" "no_plain_pii" || break ;;
    1) submit "export_all_masked" "" "count_matches" || break ;;
    2) submit "verify_pii"        "" "hash_matches" || break ;;
  esac
  done

# ─── F. Hardening/Debug (15) ───
log "F. Hardening/Debug (15)"
for i in $(seq 0 14); do
  case $((i % 3)) in
    0) submit "hardening"   "" "all_locks_present" || break ;;
    1) submit "debug"       "" "no_errors" || break ;;
    2) submit "dual_verify" "" "two_independent" || break ;;
  esac
  done

# ─── G. AI (20) ───
log "G. AI (20)"
AI_ACTIONS=(ai_review ai_parse ai_terms ai_help ai_ask ai_taskbar ai_exec_full ai_exec_scan ai_exec_apply ai_exec_list)
for i in $(seq 0 19); do
  act="${AI_ACTIONS[$((i % ${#AI_ACTIONS[@]}))]}"
  submit "$act" "" "returned_valid" || break
  done

# ─── H. Address book (15) ───
log "H. Address (15)"
for i in $(seq 0 14); do
  case $((i % 3)) in
    0) submit "addr_add"     "" "no_duplicates" || break ;;
    1) submit "addr_list"    "" "count_ok" || break ;;
    2) submit "addr_history" "" "chronological" || break ;;
  esac
  done

# ─── I. Preflight/Heal (15) ───
log "I. Preflight/Heal (15)"
LAST=(preflight self_heal ownership check_timeouts refund_status add_term show_rates update_rate convert buyer_final_decision)
for i in $(seq 0 14); do
  act="${LAST[$((i % ${#LAST[@]}))]}"
  submit "$act" "" "exit_zero" || break
  done

# ─── добити до рівно $TARGET ───
while [ "$SUBMITTED" -lt "$TARGET" ]; do
  submit "idealize_sweep" "" "idempotent" || break
done

log "✅ подано рівно: $SUBMITTED"
log "menu queue: $(rd llen cybra:menu:queue)"

# ─── Чекати, поки menu-worker розбере ───
log "→ чекаю обробки menu-worker (до 15 хв)"
BEFORE=$(rd llen cybra:parliament:results)
parliament_wait 900 0 || true

# Простий wait-цикл по menu-черзі
for _ in $(seq 1 180); do
  q=$(rd llen cybra:menu:queue)
  [ "$q" -eq 0 ] && break
  sleep 3
done

AFTER=$(rd llen cybra:parliament:results)
log "results: $BEFORE → $AFTER (+$((AFTER-BEFORE)))"
log "menu queue залишок: $(rd llen cybra:menu:queue)"
log "level: $(cat state/cybra.level 2>/dev/null || echo ?)/7"

./cybra_parliament_snapshot.sh "menu160_v2_$(date +%s)" 2>&1 | tail -3
