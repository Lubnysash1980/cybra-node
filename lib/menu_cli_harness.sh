#!/data/data/com.termux/files/usr/bin/bash
# MENU CLI HARNESS — виконує menu дії без інтерактиву
# usage:
#   source lib/menu_cli_harness.sh
#   run_menu_action <option_number> param1 param2 ...
set -u
MENU_BIN="${MENU_BIN:-$HOME/CYBRA/modules/module_19_contract_tui_menu/bin}"
MENU="${MENU:-$MENU_BIN/cybra_menu.sh}"

# Мапа: назва дії → номер опції в меню
declare -gA MENU_IDX=(
  [create_contract]=1
  [list_contracts]=2
  [show_status]=3
  [generate_links]=4
  [confirm_link]=5
  [debug]=6
  [dual_license_ledger]=7
  [creation_license]=8
  [hardening]=9
  [buyer_final_decision]=10
  [create_invoice]=11
  [add_line]=12
  [show_invoice]=13
  [finalize_invoice]=14
  [export_masked]=15
  [export_all_masked]=16
  [verify_pii]=17
  [add_term]=18
  [show_rates]=19
  [update_rate]=20
  [convert]=21
  [preflight]=22
  [self_heal]=23
  [dual_verify]=24
  [ownership]=25
  [ai_review]=26
  [ai_parse]=27
  [ai_terms]=28
  [ai_help]=29
  [ai_ask]=30
  [ai_taskbar]=31
  [ai_exec_full]=284
  [ai_exec_scan]=285
  [ai_exec_apply]=286
  [ai_exec_list]=287
  [addr_add]=290
  [addr_list]=298
  [addr_history]=299
)

# Виявити параметри, які очікує дія
discover_params(){
  local action="$1"
  awk "/^action_${action}\\(\\)/,/^}/" "$MENU" 2>/dev/null \
    | grep -oE 'read( -r)?( -p "[^"]*")?( -a)? [a-zA-Z_][a-zA-Z0-9_]*' \
    | awk '{print $NF}' | tr -d '\r'
}

# Виконати дію через stdin
run_menu_action(){
  local action="$1"; shift
  local opt="${MENU_IDX[$action]:-}"
  [ -z "$opt" ] && { echo "{\"error\":\"unknown action: $action\"}"; return 1; }
  [ -f "$MENU" ] || { echo "{\"error\":\"menu not found\"}"; return 1; }

  # Послідовність stdin:
  #   <opt>\n param1\n param2\n ... \n\n q\n
  # (порожній рядок + q — щоб вийти з інтерактивного циклу)
  {
    echo "$opt"
    for p in "$@"; do echo "$p"; done
    echo ""     # пауза після дії (read -r _)
    echo ""     # ще одна (деякі дії мають дві)
    echo "q"    # вихід
    echo "q"
    echo "q"
  } | timeout 3 bash "$MENU" 2>&1
}

# JSON-обгортка для зручності

# Визначити успіх навіть якщо меню не вийшло чисто
detect_success(){
  local action="$1" output="$2"
  # ознаки успіху для конкретних дій
  case "$action" in
    create_contract)
      printf '%s' "$output" | grep -qE 'OK: C-|CONTRACT_ID: C-' && return 0 ;;
    generate_links)
      printf '%s' "$output" | grep -qE 'L-|LINK_ID|Generated|згенеровано' && return 0 ;;
    confirm_link)
      printf '%s' "$output" | grep -qE 'CONFIRMED|confirmed|OK' && return 0 ;;
    create_invoice)
      printf '%s' "$output" | grep -qE 'INV-|Invoice|INVOICE' && return 0 ;;
    add_line)
      printf '%s' "$output" | grep -qE 'ADDED|added|Додано|line' && return 0 ;;
    finalize_invoice)
      printf '%s' "$output" | grep -qE 'FINAL|final|sealed|OK' && return 0 ;;
    addr_add)
      printf '%s' "$output" | grep -qE 'added|ADDED|OK|додано' && return 0 ;;
    *)
      # для решти — не вважаємо "Not found"/"Невідома опція" за провал
      if printf '%s' "$output" | grep -qE 'Невідома опція'; then
        # якщо після цього є реальний результат — успіх
        printf '%s' "$output" | grep -qE 'OK:|CONTRACT_ID|LINK_ID|CONFIRMED|Перевірено|---' && return 0
        return 1
      fi
      # немає ознак помилки — вважаємо успіхом
      printf '%s' "$output" | grep -qE 'Not found|NOT FOUND|Помилка|Fail|fail' && return 1
      return 0 ;;
  esac
  return 1
}


# Визначити успіх навіть якщо меню не вийшло чисто
detect_success(){
  local action="$1" output="$2"
  # ознаки успіху для конкретних дій
  case "$action" in
    create_contract)
      printf '%s' "$output" | grep -qE 'OK: C-|CONTRACT_ID: C-' && return 0 ;;
    generate_links)
      printf '%s' "$output" | grep -qE 'L-|LINK_ID|Generated|згенеровано' && return 0 ;;
    confirm_link)
      printf '%s' "$output" | grep -qE 'CONFIRMED|confirmed|OK' && return 0 ;;
    create_invoice)
      printf '%s' "$output" | grep -qE 'INV-|Invoice|INVOICE' && return 0 ;;
    add_line)
      printf '%s' "$output" | grep -qE 'ADDED|added|Додано|line' && return 0 ;;
    finalize_invoice)
      printf '%s' "$output" | grep -qE 'FINAL|final|sealed|OK' && return 0 ;;
    addr_add)
      printf '%s' "$output" | grep -qE 'added|ADDED|OK|додано' && return 0 ;;
    *)
      # для решти — не вважаємо "Not found"/"Невідома опція" за провал
      if printf '%s' "$output" | grep -qE 'Невідома опція'; then
        # якщо після цього є реальний результат — успіх
        printf '%s' "$output" | grep -qE 'OK:|CONTRACT_ID|LINK_ID|CONFIRMED|Перевірено|---' && return 0
        return 1
      fi
      # немає ознак помилки — вважаємо успіхом
      printf '%s' "$output" | grep -qE 'Not found|NOT FOUND|Помилка|Fail|fail' && return 1
      return 0 ;;
  esac
  return 1
}

json_result(){
  local action="$1" status="$2" output="$3"
  printf '%s' "$output" | python3 -c "
import sys, json, time, re
raw = sys.stdin.read()
clean = re.sub(r'\x1b\[[0-9;]*[a-zA-Z]', '', raw)
clean = re.sub(r'\x1b\[3J', '', clean)
lines = clean.split(chr(10))
filtered = []
for line in lines:
    s = line.strip()
    if re.match(r'^[\U0001F300-\U0001F9FF]\s*\[\d+\]', s): continue
    if '═══' in s: continue
    if 'CYBRA CONTRACT MANAGER' in s: continue
    if 'READY' in s and 'BSC' in s: continue
    if 'modules' in s and 'contracts' in s and 'links' in s: continue
    if s.startswith('\U0001F550'): continue
    if s in ('До побачення.',): continue
    if re.match(r'^\s*[───]+\s*\S+\s*[───]+$', s): continue
    if s in ('ОСНОВНЕ','INVOICE','PII MASK','REFUND','ВАЛЮТИ','СИСТЕМА','AI (офлайн)','AI EVOLUTION','ADDRESS BOOK','INTEGRATIONS','EXPORT / BACKUP','MULTI-CHAIN','DISPUTE / AUDIT'): continue
    filtered.append(line.rstrip())
while filtered and not filtered[0].strip(): filtered.pop(0)
while filtered and not filtered[-1].strip(): filtered.pop()
result = chr(10).join(filtered)
# спробувати витягнути найбільш релевантний фрагмент
import re as _re
m = _re.search(r'Вибір:\s*\n([\s\S]*?)(?:\n\s*───|\Z)', clean)
if m:
    cand = m.group(1).strip()
    if cand and len(cand) < 2000:
        result = cand
print(json.dumps({
    'action': sys.argv[1] if len(sys.argv)>1 else '?',
    'status': sys.argv[2] if len(sys.argv)>2 else '?',
    'output': result[:1500],
    'ts': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())
}, ensure_ascii=False))
" "$action" "$status"
}
