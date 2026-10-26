#!/data/data/com.termux/files/usr/bin/bash
# BAR MENU 160 CONTRACTS — створити 160 контрактів + bar_menu_160.contract.json
set -uo pipefail
CYBRA="$HOME/CYBRA"; cd "$CYBRA" || exit 1
TS=$(date -u +%FT%TZ)
LOG="$CYBRA/logs/bar_menu_160_$TS.log"
mkdir -p "$CYBRA/logs" "$CYBRA/state/contracts" "$CYBRA/public/contracts" "$CYBRA/links"
log(){ echo "[$(date -u +%H:%M:%SZ)] $*" | tee -a "$LOG"; }

TARGET=160
CREATED=0
SKIPPED=0
FAIL=0

# ─── detect CLI ───
CLI=""
for f in bin/cybra_contract_cli.sh cybra_contract_cli.sh; do
  [ -f "$f" ] && CLI="$f" && break
done
[ -z "$CLI" ] && { log "❌ contract CLI missing"; exit 1; }
log "  CLI: $CLI"

# ─── helper: create one contract ───
create_contract() {
  local n="$1"
  local buyer="0xBUY$(printf '%040d' "$n")"
  local seller="0xSEL$(printf '%040d' "$n")"
  local amount="1000000000000000000"  # 1 token (18 decimals)
  local token="BNB"

  out=$(bash "$CLI" create "$buyer" "$seller" "$amount" "$token" 2>&1)
  rc=$?
  if [ "$rc" -eq 0 ] && echo "$out" | grep -q '"status":"ok"'; then
    cid=$(echo "$out" | python3 -c "import sys,json;print(json.load(sys.stdin).get('contract_id',''))" 2>/dev/null || echo "?")
    log "  [$n] ✅ $cid"
    CREATED=$((CREATED+1))
    return 0
  else
    log "  [$n] ❌ rc=$rc: $(echo "$out" | head -1)"
    FAIL=$((FAIL+1))
    return 1
  fi
}

log "═══ BAR MENU 160 CONTRACTS ═══"
log "  target: $TARGET"
log ""

# ─── loop 1..160 ───
for n in $(seq 1 $TARGET); do
  # contract
  create_contract "$n"

  # push menu item (для menu-worker)
  ITEM=$(printf '{"id":"bar_%03d","n":%d,"title":"Bar item %d","level":%d}' \
    "$n" "$n" "$n" $(( (n % 7) + 1 )))
  echo "$ITEM" | redis-cli -x rpush cybra:menu:pending >/dev/null 2>&1 || true

  # throttle (RAM guard)
  if [ $((n % 20)) -eq 0 ]; then
    RAM=$(free -m 2>/dev/null | awk '/Mem:/{printf "%d",$3/$2*100}')
    log "  ── $n/160  RAM=${RAM}%  ──"
    [ "${RAM:-0}" -ge 88 ] && { log "  RAM high, sleep 10s"; sleep 10; }
    sleep 2
  fi
done

log ""
log "═══ RESULT ═══"
log "  created: $CREATED/$TARGET"
log "  failed:  $FAIL"

# ─── binmix (якщо є) ───
if [ -f bin/cybra_binmix ] && [ "$(redis-cli llen cybra:menu:pending 2>/dev/null || echo 0)" -gt 0 ]; then
  log ""
  log "  ── binmix dispatch ──"
  bash bin/cybra_binmix start >/dev/null 2>&1 || true
  sleep 30
  PENDING=$(redis-cli llen cybra:menu:pending 2>/dev/null || echo 0)
  QUEUE=$(redis-cli llen cybra:menu:queue 2>/dev/null || echo 0)
  RESULTS=$(redis-cli llen cybra:menu:results 2>/dev/null || echo 0)
  log "  pending=$PENDING queue=$QUEUE results=$RESULTS"
fi

# ─── bar_menu_160.contract.json ───
if [ "$CREATED" -ge 1 ]; then
  CONTRACT_FILE="state/contracts/bar_menu_160.contract.json"
  HASH=$( { echo "target=$TARGET"; redis-cli hgetall "cybra:bar:menu" 2>/dev/null; ls public/contracts/*.env 2>/dev/null | head -160; } | sha256sum | awk '{print $1}')
  SIG=$(printf '%s%s' "$HASH" "$TS" | sha256sum | awk '{print $1}')
  cat > "$CONTRACT_FILE" <<EOF
{
  "module": "bar_keepers",
  "menu_size": $TARGET,
  "created": $CREATED,
  "failed": $FAIL,
  "achieved_at": "$TS",
  "state_hash": "$HASH",
  "signature": "$SIG",
  "target_key": "public/contracts/*.env",
  "cybra_token": "0x74dA52028E42A37bc89E05c2fD5c52daBE4CB48f",
  "commission_pct": 5
}
EOF
  log "  📝 contract: $CONTRACT_FILE"
  log "  hash: $HASH"
fi

# ─── persist snapshot ───
mkdir -p state/snapshots
TOTAL_ENV=$(ls public/contracts/*.env 2>/dev/null | grep -v masked | wc -l)
TOTAL_JSON=$(ls public/contracts/*.json 2>/dev/null | grep -v masked | wc -l)
TOTAL_LINK=$(ls links/*.link 2>/dev/null | wc -l)
cat > state/snapshots/bar_menu_160.json <<EOF
{
  "ts": "$TS",
  "target": $TARGET,
  "created": $CREATED,
  "failed": $FAIL,
  "contracts_env": $TOTAL_ENV,
  "contracts_json": $TOTAL_JSON,
  "links": $TOTAL_LINK,
  "ok": $([ "$CREATED" -ge "$TARGET" ] && echo true || echo false),
  "detail": "$CREATED/$TARGET"
}
EOF

log ""
log "═══ FINAL ═══"
log "  contracts .env: $TOTAL_ENV"
log "  contracts .json: $TOTAL_JSON"
log "  links: $TOTAL_LINK"
log "  signed: $([ -f "$CONTRACT_FILE" ] && echo yes || echo no)"

exit $([ "$CREATED" -ge "$TARGET" ] && echo 0 || echo 1)
