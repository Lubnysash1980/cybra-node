#!/data/data/com.termux/files/usr/bin/bash
# TEST: чи AI реально створює контракти через базовий скрипт
set -uo pipefail
CYBRA="$HOME/CYBRA"; cd "$CYBRA" || exit 1
TID="TEST-$(date +%s)"
REPORT="$CYBRA/state/ai_contract_test_$TID.json"

say(){ printf '%s\n' "$*"; }
br(){ say "──────────────────────────────────────"; }
hdr(){ say ""; say "═══ $* ═══"; }

hdr "TEST 1: які AI/contract скрипти реально існують"

# 1.1 AI scripts
say ""
say "── AI-скрипти (перевірка чи не заглушка) ──"
for f in cybra_ai_executor.sh cybra_local_ai.sh cybra_ai_block_enforcer.py \
         modules/module_19_contract_tui_menu/bin/cybra_local_ai.sh \
         modules/module_19_contract_tui_menu/bin/cybra_ai_executor.sh \
         ai_director.py run_answer_engine.sh auto_ai.sh chat.sh; do
  if [ -f "$CYBRA/$f" ]; then
    bytes=$(wc -c < "$CYBRA/$f")
    lines=$(wc -l < "$CYBRA/$f")
    stub=0
    grep -qiE 'AI-INTEGRATED|потребує наповнення|smart-stub|created by fix_missing' "$CYBRA/$f" 2>/dev/null && stub=1
    mark=$([ "$stub" = "1" ] && echo "STUB" || echo "REAL")
    printf "  [%s] %6dB %4dL  %s\n" "$mark" "$bytes" "$lines" "$f"
  fi
done

# 1.2 Contract CLI
say ""
say "── Contract CLI (базовий створювач) ──"
for f in bin/cybra_contract_cli.sh cybra_contract_cli.sh \
         modules/module_19_contract_tui_menu/bin/cybra_contract_cli.sh; do
  if [ -f "$CYBRA/$f" ]; then
    bytes=$(wc -c < "$CYBRA/$f")
    printf "  ✅ %6dB  %s\n" "$bytes" "$f"
    say "     перші 3 рядки:"
    head -3 "$CYBRA/$f" | sed 's/^/     /'
  fi
done

hdr "TEST 2: чи contract CLI створює контракт (без AI)"

# знайти contract CLI
CLI=""
for f in bin/cybra_contract_cli.sh cybra_contract_cli.sh; do
  [ -f "$CYBRA/$f" ] && { CLI="$CYBRA/$f"; break; }
done

if [ -z "$CLI" ]; then
  say "❌ contract CLI не знайдено — AI не має що викликати"
  CLI_STATUS="missing"
else
  say "  CLI: $CLI"
  say "  спроба: create buyer_$TID seller_$TID 100 USDT"
  out=$("$CLI" create "buyer_$TID" "seller_$TID" "100" "USDT" 2>&1)
  rc=$?
  say "  rc=$rc"
  say "  output:"
  printf '%s\n' "$out" | head -10 | sed 's/^/    /'
  CLI_STATUS=$([ "$rc" -eq 0 ] && echo "ok" || echo "fail")

  # чи контракт реально створено?
  CONTRACT_ID=$(printf '%s\n' "$out" | grep -oE 'C-[0-9]+-[a-f0-9]+' | head -1)
  if [ -n "$CONTRACT_ID" ]; then
    say "  ✅ contract_id: $CONTRACT_ID"
    say "  перевірка файлу:"
    ls -la "$CYBRA/public/contracts/$CONTRACT_ID"* 2>/dev/null | head -3 | sed 's/^/    /'
    CONTRACT_STATUS="created:$CONTRACT_ID"
  else
    CONTRACT_STATUS="no_id"
  fi
fi

hdr "TEST 3: чи AI аналізує контракт (реальний виклик)"

# спроби різних AI executor-ів
AI_OK=0
AI_CMD=""
AI_OUT=""

say ""
say "── Спроба 1: cybra_ai_executor.sh ──"
F="$CYBRA/modules/module_19_contract_tui_menu/bin/cybra_ai_executor.sh"
[ -f "$F" ] || F="$CYBRA/cybra_ai_executor.sh"
if [ -f "$F" ]; then
  out=$(timeout 15 bash "$F" "analyze contract test" 2>&1); rc=$?
  say "  rc=$rc  first line: $(printf '%s\n' "$out" | head -1)"
  [ "$rc" -eq 0 ] && [ -n "$out" ] && { AI_OK=1; AI_CMD="$F"; AI_OUT="$out"; }
fi

say ""
say "── Спроба 2: cybra_local_ai.sh ──"
F="$CYBRA/modules/module_19_contract_tui_menu/bin/cybra_local_ai.sh"
[ -f "$F" ] || F="$CYBRA/cybra_local_ai.sh"
if [ -f "$F" ]; then
  out=$(timeout 15 bash "$F" "what is a smart contract" 2>&1); rc=$?
  say "  rc=$rc  first line: $(printf '%s\n' "$out" | head -1)"
  [ "$rc" -eq 0 ] && [ -n "$out" ] && [ "$AI_OK" = "0" ] && { AI_OK=1; AI_CMD="$F"; AI_OUT="$out"; }
fi

say ""
say "── Спроба 3: ai_director.py ──"
F="$CYBRA/ai_director.py"
if [ -f "$F" ]; then
  out=$(timeout 15 python3 "$F" "analyze contract" 2>&1); rc=$?
  say "  rc=$rc  first line: $(printf '%s\n' "$out" | head -1)"
  [ "$rc" -eq 0 ] && [ -n "$out" ] && [ "$AI_OK" = "0" ] && { AI_OK=1; AI_CMD="$F"; AI_OUT="$out"; }
fi

AI_STATUS=$([ "$AI_OK" = "1" ] && echo "works:$AI_CMD" || echo "none_works")

hdr "TEST 4: чи HIDL dispatch до AI"

say "  спроба HIDL → module_40 (ai_analyze)"
~/CYBRA/bin/cybra_hidl.py 40 execute analyze "test contract $TID" 2>&1 | sed 's/^/    /'
sleep 4

# останній результат HIDL для module_40
LAST=$(tail -20 "$CYBRA/state/hidl/events.jsonl" 2>/dev/null | grep '"module": 40' | tail -1)
if [ -n "$LAST" ]; then
  say "  HIDL response:"
  printf '%s\n' "$LAST" | python3 -c "import sys,json;d=json.load(sys.stdin);print(f\"    status={d.get('status')} rc={d.get('rc')} elapsed={d.get('elapsed_sec')}s\");print(f\"    stdout: {d.get('stdout','')[:120]}\")" 2>/dev/null
  HIDL_STATUS=$(printf '%s\n' "$LAST" | python3 -c "import sys,json;print(json.load(sys.stdin).get('status','?'))" 2>/dev/null)
else
  HIDL_STATUS="no_response"
fi

hdr "TEST 5: реальний contract в git"

say "  останні 3 контракти в git:"
git --no-pager log -5 --oneline -- 'public/contracts/*' 2>/dev/null | head -5 | sed 's/^/    /'

say ""
say "  свіжі контракти на диску:"
find "$CYBRA/public/contracts" -name 'C-*.json' -mmin -60 2>/dev/null | head -5 | while read f; do
  say "    $(basename "$f")  ($(wc -c < "$f")B)"
done

hdr "RESULT"

python3 - "$REPORT" "$TID" "$CLI_STATUS" "$CONTRACT_STATUS" "$AI_STATUS" "$HIDL_STATUS" <<'PY'
import sys, json
from datetime import datetime, timezone
report, tid, cli, contract, ai, hidl = sys.argv[1:]
data = {
    "ts": datetime.now(timezone.utc).isoformat(),
    "test_id": tid,
    "contract_cli": cli,
    "contract_created": contract,
    "ai_executor": ai,
    "hidl_to_ai": hidl,
    "verdict": {
        "contract_pipeline": "OK" if "created" in contract else ("CLI_OK_NO_ID" if cli == "ok" else "BROKEN"),
        "ai_pipeline": "OK" if "works" in ai else "BROKEN",
        "hidl_pipeline": "OK" if hidl == "ok" else hidl.upper(),
    }
}
open(report, "w").write(json.dumps(data, indent=2, ensure_ascii=False))
print(f"  contract CLI:   {cli}")
print(f"  contract real:  {contract}")
print(f"  AI executor:    {ai}")
print(f"  HIDL → AI:      {hidl}")
print(f"\n  report: {report}")
PY

echo ""
say "═══ ЩО ЦЕ ЗНАЧИТЬ ═══"
say ""
say "  contract_created: created:C-...  → контракт реально створено через CLI"
say "  ai_executor: works:path         → AI-скрипт відповідає (не заглушка)"
say "  hidl_to_ai: ok                  → HIDL викликав AI через module_40"
say ""
say "  якщо всі три OK — AI реально пише контракти"
say "  якщо ai_executor=BROKEN — AI-скрипт або відсутній, або не відповідає"
say "  якщо contract_created=no_id — CLI є, але не створює файлів"
