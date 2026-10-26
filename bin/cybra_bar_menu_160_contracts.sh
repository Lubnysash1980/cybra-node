#!/data/data/com.termux/files/usr/bin/bash
set -uo pipefail
CYBRA="$HOME/CYBRA"; cd "$CYBRA" || exit 1
TS=$(date -u +%FT%TZ); TARGET=160; CREATED=0; FAIL=0
WRITER=""
[ -x bin/cybra_contract_create.sh ] && WRITER="bin/cybra_contract_create.sh"
[ -z "$WRITER" ] && { echo "❌ no cybra_contract_create.sh"; exit 1; }
echo "═══ BAR MENU 160 ═══  writer: $WRITER"
for n in $(seq 1 $TARGET); do
  out=$(bash "$WRITER" "0xBUY$(printf '%040d' $n)" "0xSEL$(printf '%040d' $n)" "1000000000000000000" "BNB" 2>&1)
  rc=$?
  if [ "$rc" -eq 0 ] && echo "$out" | grep -q '"status":"ok"'; then
    CREATED=$((CREATED+1))
  else
    FAIL=$((FAIL+1)); echo "  [$n] ❌ rc=$rc: $(echo "$out" | head -c 80)"
  fi
  printf '{"id":"bar_%03d","n":%d,"title":"Bar item %d","level":%d}' $n $n $n $(( (n%7)+1 )) | redis-cli -x rpush cybra:menu:pending >/dev/null 2>&1
  [ $((n % 40)) -eq 0 ] && echo "  ── $n/160 ── (created: $CREATED, failed: $FAIL)"
done
mkdir -p state/contracts
cat > state/contracts/bar_menu_160.contract.json <<JSON
{
  "module": "bar_keepers", "menu_size": $TARGET, "created": $CREATED, "failed": $FAIL,
  "achieved_at": "$TS",
  "state_hash": "$(ls public/contracts/*.env 2>/dev/null | head -160 | xargs -r sha256sum | sha256sum | awk '{print $1}')",
  "cybra_token": "0x74dA52028E42A37bc89E05c2fD5c52daBE4CB48f", "commission_pct": 5
}
JSON
echo "═══ RESULT ═══  created: $CREATED/$TARGET  failed: $FAIL"
exit $([ "$CREATED" -ge "$TARGET" ] && echo 0 || echo 1)
