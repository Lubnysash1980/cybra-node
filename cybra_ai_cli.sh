#!/data/data/com.termux/files/usr/bin/bash
set -u
source "$HOME/CYBRA/lib/menu_cli_harness.sh"

declare -A MAP=(
  [review]="ai_review"
  [parse]="ai_parse"
  [terms]="ai_terms"
  [ask]="ai_ask"
  [help]="ai_help"
  [taskbar]="ai_taskbar"
)

SUB="${1:-help}"; shift || true
case "$SUB" in
  help|--help|-h|"")
    echo "usage: cybra_ai_cli.sh <review|parse|terms|ask|help|taskbar> [--key value ...]"
    for a in ai_review ai_parse ai_terms ai_ask ai_help ai_taskbar; do
      printf '  %-20s: %s\n' "$a" "$(discover_params "$a" | tr '\n' ' ')"
    done
    exit 0 ;;
esac
ACTION="${MAP[$SUB]:-}"
[ -z "$ACTION" ] && { echo "{\"error\":\"unknown: $SUB\"}"; exit 1; }

declare -a ORDERED=(); declare -A KV=(); JSON=""
while [ $# -gt 0 ]; do
  case "$1" in
    --json) JSON="${2:-}"; shift 2 ;;
    --*) KV["${1#--}"]="${2:-}"; shift 2 ;;
    *) shift ;;
  esac
done
discovered=$(discover_params "$ACTION")
for name in $discovered; do
  if [ -n "$JSON" ]; then
    val=$(printf '%s' "$JSON" | python3 -c "import sys,json;d=json.load(sys.stdin);print(d.get('$name',''))" 2>/dev/null)
  else
    val="${KV[$name]:-}"
  fi
  ORDERED+=("$val")
done

out=$(run_menu_action "$ACTION" "${ORDERED[@]}"); rc=$?
if [ $rc -eq 0 ] || detect_success "$ACTION" "$out"; then
  json_result "$ACTION" "done" "$out"
else
  json_result "$ACTION" "failed" "$out"
fi
