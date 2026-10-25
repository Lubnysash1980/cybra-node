#!/data/data/com.termux/files/usr/bin/bash
# Contract CLI — прямий, без меню (меню створене для інтерактиву)
set -eu
CYBRA="$HOME/CYBRA"; cd "$CYBRA" || exit 1

case "${1:-help}" in
  create)
    shift
    out=$(bash bin/cybra_contract_create.sh "$@")
    echo "$out"
    ;;
  list)
    n=$(ls public/contracts/*.env 2>/dev/null | wc -l)
    echo "{\"action\":\"list_contracts\",\"status\":\"ok\",\"count\":$n}"
    ls public/contracts/*.env 2>/dev/null | tail -10 | while read f; do
      cid=$(basename "$f" .env)
      buyer=$(grep -m1 '^BUYER=' "$f" 2>/dev/null | cut -d= -f2- || echo "?")
      seller=$(grep -m1 '^SELLER=' "$f" 2>/dev/null | cut -d= -f2- || echo "?")
      stage=$(grep -m1 '^STAGE=' "$f" 2>/dev/null | cut -d= -f2- || echo "?")
      echo "  $cid  buyer=$buyer  seller=$seller  stage=$stage"
    done
    ;;
  status)
    [ -z "${2:-}" ] && { echo '{"error":"need contract_id"}'; exit 1; }
    f="public/contracts/$2.env"
    [ ! -f "$f" ] && { echo "{\"error\":\"not found: $2\"}"; exit 1; }
    echo "{\"action\":\"status\",\"contract_id\":\"$2\"}"
    cat "$f" | sed 's/^/  /'
    ;;
  show)
    cat "public/contracts/${2:-}.env" 2>/dev/null || { echo '{"error":"not found"}'; exit 1; }
    ;;
  ai_review)
    [ -z "${2:-}" ] && { echo '{"error":"need contract_id"}'; exit 1; }
    # копіювати в модуль contracts
    mkdir -p modules/module_19_contract_tui_menu/contracts
    cp "public/contracts/$2.env" modules/module_19_contract_tui_menu/contracts/ 2>/dev/null
    CYBRA_MOD19_ROOT="$HOME/CYBRA/modules/module_19_contract_tui_menu" \
      bash modules/module_19_contract_tui_menu/bin/cybra_local_ai.sh review "$2"
    ;;
  generate_links|confirm_link|debug|dual_license|creation_license|hardening|dual_verify)
    # ці все ще через меню (інтерактивні)
    source lib/menu_cli_harness.sh
    declare -A MAP=(
      [generate_links]="generate_links"
      [confirm_link]="confirm_link"
      [debug]="debug"
      [dual_license]="dual_license_ledger"
      [creation_license]="creation_license"
      [hardening]="hardening"
      [dual_verify]="dual_verify"
    )
    ACT="${MAP[$1]}"; shift
    out=$(run_menu_action "$ACT" "$@")
    echo "{\"action\":\"$ACT\",\"status\":\"done\",\"output\":$(printf '%s' "$out" | python3 -c 'import sys,json;print(json.dumps(sys.stdin.read()))')}"
    ;;
  help|--help|-h|"")
    cat <<USAGE
usage: cybra_contract_cli.sh <action> [params]

  create   BUYER SELLER AMOUNT_WEI [TOKEN]   → створює .env + .json + links
  list                                       → показує всі контракти
  status   CONTRACT_ID                       → стан контракту
  show     CONTRACT_ID                       → сирі дані
  generate_links C                           → (через меню)
  confirm_link L W                           → (через меню)
  debug | dual_license | creation_license | hardening | dual_verify

Приклад:
  cybra_contract_cli.sh create 0xBUYER 0xSELLER 1000000000000000000 BNB
USAGE
    ;;
  *)
    echo '{"error":"unknown action"}'
    exit 1
    ;;
esac
