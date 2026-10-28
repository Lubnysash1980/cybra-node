#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
cd "$HOME/CYBRA"
mkdir -p lib bin state/private logs

# 0. openssl
command -v openssl >/dev/null 2>&1 || pkg install -y openssl-tool >/dev/null 2>&1 || true

# 1. lib
cat > lib/cybra_privacy.sh <<'LIB'
#!/data/data/com.termux/files/usr/bin/bash
: "${CYBRA:=$HOME/CYBRA}"
CKEY_FILE="$HOME/.cybra_privacy.key"
CKEY="${CYBRA_PRIVACY_KEY:-}"
[ -z "$CKEY" ] && [ -f "$CKEY_FILE" ] && CKEY="$(cat "$CKEY_FILE" 2>/dev/null)"
[ -z "$CKEY" ] && CKEY="__uninit__"

priv_ready(){ [ "$CKEY" != "__uninit__" ] && command -v openssl >/dev/null 2>&1; }
priv_hash(){ printf '%s' "$1" | sha256sum | cut -c1-32; }
priv_enc(){ command -v openssl >/dev/null 2>&1 && printf '%s' "$1" | openssl enc -aes-256-cbc -pbkdf2 -a -A -k "$CKEY" 2>/dev/null | tr -d '\n' || printf '%s' "$1"; }
priv_dec(){ command -v openssl >/dev/null 2>&1 && printf '%s' "$1" | openssl enc -d -aes-256-cbc -pbkdf2 -a -A -k "$CKEY" 2>/dev/null || printf '%s' "$1"; }

priv_bal(){
  local addr="$1" raw
  raw=$(redis-cli hget cybra:token:balances "h:$(priv_hash "$addr")" 2>/dev/null || true)
  [ -n "$raw" ] && { priv_dec "$raw"; return 0; }
  redis-cli hget cybra:token:balances "$addr" 2>/dev/null || echo 0
}

priv_set_bal(){
  local addr="$1" amt="$2"
  if [ "$(redis-cli get cybra:privacy:enabled 2>/dev/null)" = "1" ]; then
    redis-cli hset cybra:token:balances "h:$(priv_hash "$addr")" "$(priv_enc "$amt")" >/dev/null
    redis-cli hdel cybra:token:balances "$addr" >/dev/null 2>&1 || true
  else
    redis-cli hset cybra:token:balances "$addr" "$amt" >/dev/null
  fi
}

priv_push_history(){
  local kind="$1" from="$2" to="$3" amt="$4"
  if [ "$(redis-cli get cybra:privacy:enabled 2>/dev/null)" = "1" ]; then
    local hf ht ae
    hf=$(priv_hash "salt:$from"); ht=$(priv_hash "salt:$to"); ae=$(priv_enc "$amt")
    local entry
    entry=$(python3 -c "import json,os,time;print(json.dumps({'k':'$kind','hf':'$hf','ht':'$ht','ae':'$ae','ts':int(time.time()),'ref':os.urandom(4).hex()},separators=(',',':')))")
    printf '%s' "$entry" | redis-cli -x rpush cybra:token:history >/dev/null
  else
    printf '%s|%s|%s|%s|%s\n' "$kind" "$from" "$to" "$amt" "$(date -u +%FT%TZ)" | redis-cli -x rpush cybra:token:history >/dev/null
  fi
}
LIB
chmod +x lib/cybra_privacy.sh

# 2. patch module_281
P="modules/module_281_token_system/main.sh"
if [ -f "$P" ] && ! grep -q cybra_privacy "$P"; then
python3 - "$P" <<'PY'
import sys; p=sys.argv[1]; t=open(p).read()
t = t.replace('CYBRA="${CYBRA:-$HOME/CYBRA}"; cd "$CYBRA" 2>/dev/null || exit 1',
              'CYBRA="${CYBRA:-$HOME/CYBRA}"; cd "$CYBRA" 2>/dev/null || exit 1\nsource "$CYBRA/lib/cybra_privacy.sh" 2>/dev/null || true')
t = t.replace('get_bal(){ redis-cli hget "$KEY_BAL" "$1" 2>/dev/null || echo 0; }','get_bal(){ priv_bal "$1"; }')
t = t.replace('set_bal(){ redis-cli hset "$KEY_BAL" "$1" "$2" >/dev/null; }','set_bal(){ priv_set_bal "$1" "$2"; }')
t = t.replace('''push_hist(){
  local e="$1|$2|$3|$4|$(date -u +%FT%TZ)"
  echo "$e" | redis-cli -x rpush "$KEY_HIST" >/dev/null
}''','push_hist(){ priv_push_history "$1" "$2" "$3" "$4"; }')
open(p,"w").write(t); print("✅ 281 patched")
PY
fi

# 3. patch module_282
P="modules/module_282_nfc_payment/main.sh"
if [ -f "$P" ] && ! grep -q cybra_privacy "$P"; then
python3 - "$P" <<'PY'
import sys; p=sys.argv[1]; t=open(p).read()
t = t.replace('CYBRA="${CYBRA:-$HOME/CYBRA}"; cd "$CYBRA" 2>/dev/null || exit 1',
              'CYBRA="${CYBRA:-$HOME/CYBRA}"; cd "$CYBRA" 2>/dev/null || exit 1\nsource "$CYBRA/lib/cybra_privacy.sh" 2>/dev/null || true')
open(p,"w").write(t); print("✅ 282 patched")
PY
fi

# 4. patch module_280 — pay через privacy
P="modules/module_280_payment_system/main.sh"
if [ -f "$P" ] && ! grep -q cybra_privacy "$P"; then
python3 - "$P" <<'PY'
import sys; p=sys.argv[1]; t=open(p).read()
t = t.replace('CYBRA="${CYBRA:-$HOME/CYBRA}"; cd "$CYBRA" 2>/dev/null || exit 1',
              'CYBRA="${CYBRA:-$HOME/CYBRA}"; cd "$CYBRA" 2>/dev/null || exit 1\nsource "$CYBRA/lib/cybra_privacy.sh" 2>/dev/null || true')
# pay: write history through privacy
t = t.replace(
  'echo "$ENTRY" | redis-cli -x rpush "$KEY_HISTORY" >/dev/null',
  'priv_push_history "payment" "$LABEL" "$TO" "$AMOUNT"'
)
open(p,"w").write(t); print("✅ 280 patched")
PY
fi

# 5. CLI
cat > bin/cybra_private.sh <<'CLI'
#!/data/data/com.termux/files/usr/bin/bash
set -u
CYBRA="$HOME/CYBRA"; cd "$CYBRA" || exit 1
source "$CYBRA/lib/cybra_privacy.sh"

init(){
  [ -f "$HOME/.cybra_privacy.key" ] && { echo "🔐 exists: $HOME/.cybra_privacy.key"; return 0; }
  openssl rand -hex 32 > "$HOME/.cybra_privacy.key"
  chmod 600 "$HOME/.cybra_privacy.key"
  echo "🔐 key: $HOME/.cybra_privacy.key"
  echo "   BACKUP — без нього дані не відновити"
}

enable(){
  [ ! -f "$HOME/.cybra_privacy.key" ] && { echo "run init"; exit 1; }
  CKEY="$(cat "$HOME/.cybra_privacy.key")"
  redis-cli set cybra:privacy:enabled 1 >/dev/null
  echo "🔒 privacy ENABLED"
  migrate
}

disable(){
  redis-cli del cybra:privacy:enabled >/dev/null
  echo "⚠️  privacy DISABLED (нові записи plain, старі зашифровані)"
}

migrate(){
  [ ! -f "$HOME/.cybra_privacy.key" ] && { echo "run init"; exit 1; }
  CKEY="$(cat "$HOME/.cybra_privacy.key")"
  N=0
  while read -r line; do
    [ -z "$line" ] && continue
    addr=$(printf '%s' "$line" | cut -d' ' -f1)
    val=$(printf '%s' "$line" | cut -d' ' -f2-)
    [[ "$addr" == h:* ]] && continue
    [[ "$addr" == 0x* ]] || continue
    redis-cli hset cybra:token:balances "h:$(priv_hash "$addr")" "$(priv_enc "$val")" >/dev/null
    redis-cli hdel cybra:token:balances "$addr" >/dev/null
    N=$((N+1))
  done < <(redis-cli hgetall cybra:token:balances | paste - -)
  echo "✅ migrated $N addresses"
}

status(){
  echo "─── privacy ───"
  echo "  key:     $([ -f "$HOME/.cybra_privacy.key" ] && echo yes || echo NO)"
  echo "  enabled: $(redis-cli get cybra:privacy:enabled 2>/dev/null || echo 0)"
  local leak=$(redis-cli hkeys cybra:token:balances 2>/dev/null | grep -cE '^0x[a-fA-F0-9]{40}$' || echo 0)
  echo "  plain leaks: $leak"
  echo "  balances sample:"
  redis-cli hgetall cybra:token:balances 2>/dev/null | head -4 | sed 's/^/    /'
}

case "${1:-status}" in
  init) init ;; enable) enable ;; disable) disable ;;
  migrate) migrate ;; status) status ;;
  *) echo "usage: cybra_private.sh init|enable|disable|migrate|status" ;;
esac
CLI
chmod +x bin/cybra_private.sh

# 6. guard: privacy checks
G="token_nfc_guard_handler.sh"
if [ -f "$G" ] && ! grep -q cybra:privacy:enabled "$G"; then
python3 - "$G" <<'PY'
import sys; p=sys.argv[1]; t=open(p).read()
t = t.replace('# 7. хоча б один метод оплати',
'''# 7. privacy enabled
[ "$(redis-cli get cybra:privacy:enabled 2>/dev/null)" = "1" ] || add_issue "privacy disabled"
[ -f "$HOME/.cybra_privacy.key" ] || add_issue "privacy key missing"
PLAIN_LEAK=$(redis-cli hkeys cybra:token:balances 2>/dev/null | grep -cE '^0x[a-fA-F0-9]{40}$' || echo 0)
[ "$PLAIN_LEAK" -eq 0 ] || add_issue "plain addresses in balances: $PLAIN_LEAK"

# 8. хоча б один метод оплати''', 1)
open(p,"w").write(t); print("✅ guard +privacy")
PY
fi

printf '{"ok":true,"layer":"privacy","patched":["280","281","282","guard"]}\n'
