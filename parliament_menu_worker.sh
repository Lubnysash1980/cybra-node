#!/data/data/com.termux/files/usr/bin/bash
# MENU WORKER — обробляє menu_action з окремої черги cybra:menu:queue
# Виконує реальні дії меню там, де це безпечно (без інтерактиву)
set -u
CYBRA="$HOME/CYBRA"; cd "$CYBRA" || exit 1
MENU_BIN="$CYBRA/modules/module_19_contract_tui_menu/bin"
LOG="$CYBRA/logs/menu_worker.log"; mkdir -p "$CYBRA/logs"
log(){ echo "[$(date -u +%FT%TZ)] $*" | tee -a "$LOG"; }
rd(){ redis-cli "$@" 2>/dev/null; }

# ─── Реальні handlers (тільки безпечні, без інтерактиву) ───
dispatch(){
  local action="$1" cid="${2:-}"
  case "$action" in
    # реальні CLI-обгортки
    preflight)   timeout 20 bash "$MENU_BIN/cybra_preflight.sh" 2>&1 ;;
    self_heal)   timeout 20 bash "$MENU_BIN/cybra_self_heal.sh" 2>&1 ;;
    debug)       timeout 15 bash "$MENU_BIN/cybra_health.sh" 2>&1 ;;

    # read-only меню-функції через feed порожнього stdin
    list_contracts)      ls -1 "$CYBRA/modules/module_19_contract_tui_menu/contracts" 2>/dev/null | wc -l | xargs echo "contracts:" ;;
    show_status)         cat "$CYBRA/registry/controllers.json" 2>/dev/null | head -c 200 ; echo ;;
    show_invoice)        echo "read_only:show_invoice:$cid" ;;
    show_rates)          echo "read_only:show_rates" ;;
    export_masked)       echo "read_only:export_masked" ;;
    export_all_masked)   echo "read_only:export_all_masked" ;;
    verify_pii)          echo "read_only:verify_pii" ;;
    check_timeouts)      echo "read_only:check_timeouts" ;;
    refund_status)       echo "read_only:refund_status" ;;
    addr_list)           echo "read_only:addr_list" ;;
    addr_history)        echo "read_only:addr_history" ;;
    ai_exec_list)        echo "read_only:ai_exec_list" ;;
    ai_help)             echo "read_only:ai_help" ;;

    # write-дії: НЕ виконуємо автоматично (потребують рішень)
    create_contract|generate_links|confirm_link|dual_license_ledger|creation_license|\
    create_invoice|add_line|finalize_invoice|hardening|dual_verify|\
    addr_add|ownership|add_term|update_rate|convert|buyer_final_decision|\
    ai_review|ai_parse|ai_terms|ai_ask|ai_taskbar|ai_exec_full|ai_exec_scan|ai_exec_apply)
      echo "DEFERRED:needs_manual:$action"
      return 4 ;;

    idealize_sweep)  echo "sweep_ok" ;;
    *)               echo "unknown:$action"; return 3 ;;
  esac
}

# ─── Main loop ───
log "═══ MENU WORKER START ═══"
while :; do
  rd ping | grep -q PONG || { sleep 5; continue; }
  raw=$(rd lpop cybra:menu:queue)
  [ -z "$raw" ] && { sleep 2; continue; }

  action=$(printf '%s' "$raw" | python3 -c "import sys,json;print(json.loads(sys.stdin.read()).get('action',''))" 2>/dev/null)
  cid=$(printf '%s'    "$raw" | python3 -c "import sys,json;print(json.loads(sys.stdin.read()).get('contract_id',''))" 2>/dev/null)
  tid=$(printf '%s'    "$raw" | python3 -c "import sys,json;print(json.loads(sys.stdin.read()).get('id',''))" 2>/dev/null)

  log "task=$tid action=$action cid=$cid"

  out=$(dispatch "$action" "$cid" 2>&1); rc=$?
  case $rc in
    0) status="done" ;;
    4) status="deferred" ;;
    *) status="failed" ;;
  esac

  result="{\"id\":\"$tid\",\"action\":\"$action\",\"contract_id\":\"$cid\",\"status\":\"$status\",\"rc\":$rc,\"output\":\"$(printf '%s' "$out" | head -c 500 | tr -d '\n\r"\\')\",\"ts\":\"$(date -u +%FT%TZ)\"}"
  target="cybra:menu:results"
  [ "$status" = "failed" ] && target="cybra:menu:failed"
  printf '%s' "$result" | rd -x rpush "$target" >/dev/null
  log "  → $status"
done
