#!/data/data/com.termux/files/usr/bin/bash
set -u
source "$HOME/CYBRA/lib/menu_cli_harness.sh"

usage(){
cat <<EOF
usage: cybra_contract_cli.sh <action> [param1 param2 ...]

Параметри — ПОЗИЦІЙНІ, в порядку read у меню:

  create         B S A [T]              (BUYER SELLER AMOUNT [TOKEN=BNB])
                 приклад: create 0xBUYER 0xSELLER 1000000000000000000 BNB
  list           (без параметрів)
  status         C                      (CONTRACT_ID, напр. C-1792669792)
  generate_links C                      (CONTRACT_ID)
  confirm_link   L W                    (LINK_ID WHO)
  debug          (без параметрів)
  dual_license   (без параметрів)
  creation_license (без параметрів)
  hardening      (без параметрів)
  dual_verify    (без параметрів)
EOF
}

declare -A MAP=(
  [create]="create_contract"
  [list]="list_contracts"
  [status]="show_status"
  [generate_links]="generate_links"
  [confirm_link]="confirm_link"
  [debug]="debug"
  [dual_license]="dual_license_ledger"
  [creation_license]="creation_license"
  [hardening]="hardening"
  [dual_verify]="dual_verify"
)

SUB="${1:-help}"; shift || true
case "$SUB" in help|--help|-h|"") usage; exit 0 ;; esac
ACTION="${MAP[$SUB]:-}"
[ -z "$ACTION" ] && { echo "{\"error\":\"unknown: $SUB\"}"; usage; exit 1; }

# передаємо всі аргументи як позиційні + автоматичні паузи
out=$(run_menu_action "$ACTION" "$@")
rc=$?
if [ $rc -eq 0 ] || detect_success "$ACTION" "$out"; then
  json_result "$ACTION" "done" "$out"
else
  json_result "$ACTION" "failed" "$out"
fi
