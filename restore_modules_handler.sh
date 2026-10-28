#!/data/data/com.termux/files/usr/bin/bash
# restore_modules_handler.sh — генерує реальні модулі 1-160 (add/list/delete)
set -euo pipefail
cd "$HOME/CYBRA"

read -r RANGE_START RANGE_END < <(printf '%s' "${CYBRA_TASK_JSON:-{\}}" | python3 -c 'import sys,json;d=json.load(sys.stdin);print(d.get("start",1),d.get("end",160))')

mkdir -p modules controllers logs

gen_module() {
  local n=$1
  local nn=$(printf '%03d' "$n")
  local name="module_${nn}"
  local dir="modules/module_${nn}_${name}"
  local main="$dir/main.sh"

  [ -f "$main" ] && return 0  # вже є

  mkdir -p "$dir" controllers
  cat > "$main" <<MODULE
#!/data/data/com.termux/files/usr/bin/bash
# module_${nn}: ${name}
set -u
CYBRA="\${CYBRA:-\$HOME/CYBRA}"; cd "\$CYBRA" 2>/dev/null || exit 1
LOG="\$CYBRA/logs/module_${nn}.log"; mkdir -p "\$(dirname "\$LOG")"
log(){ echo "[\$(date -u +%FT%TZ)] \$*" >> "\$LOG"; }
ACTION="\${1:-list}"; shift \$(( \$# > 0 ? 1 : 0 ))
KEY="cybra:${name}:data"
log "START action=\$ACTION"

case "\$ACTION" in
  add|create)
    [ \$# -lt 1 ] && { echo "usage: \$0 add <label> [value]"; exit 1; }
    VAL="\${2:-\$(date +%s)}"
    redis-cli hset "\$KEY" "\$1" "\$VAL" >/dev/null || { echo "FAIL"; exit 1; }
    echo "✅ \$1 = \$VAL"
    ;;
  list|status)
    N=\$(redis-cli hlen "\$KEY" 2>/dev/null || echo 0)
    echo "════ ${name} ════"
    echo "  items: \$N"
    if [ "\$N" -gt 0 ]; then
      redis-cli hgetall "\$KEY" | paste - - | head -30 | sed 's/^/  /'
    fi
    ;;
  delete|remove|rm)
    [ \$# -lt 1 ] && { echo "usage: \$0 delete <label>"; exit 1; }
    redis-cli hdel "\$KEY" "\$1" >/dev/null
    echo "✅ deleted: \$1"
    ;;
  info)
    echo "  module: ${name}"
    echo "  key:    \$KEY"
    echo "  items:  \$(redis-cli hlen "\$KEY" 2>/dev/null || echo 0)"
    ;;
  *)
    echo "════ ${name} ════"
    echo "  actions: add | list | delete | info"
    ;;
esac
rc=\$?; log "DONE rc=\$rc"; exit \$rc
MODULE
  chmod +x "$main"

  cat > "controllers/module_${nn}.ctrl.sh" <<CTRL
#!/data/data/com.termux/files/usr/bin/bash
[ -f "\$HOME/CYBRA/modules/module_${nn}_${name}/main.sh" ] || { echo "missing"; exit 2; }
bash "\$HOME/CYBRA/modules/module_${nn}_${name}/main.sh" "\$@"
CTRL
  chmod +x "controllers/module_${nn}.ctrl.sh"
}

CREATED=0; EXIST=0
for n in $(seq "$RANGE_START" "$RANGE_END"); do
  nn=$(printf '%03d' "$n")
  if ls -d modules/module_${nn}_* >/dev/null 2>&1; then
    EXIST=$((EXIST+1))
  else
    gen_module "$n" && CREATED=$((CREATED+1))
  fi
done

printf '{"ok":true,"created":%d,"existed":%d,"range":"%s-%s"}\n' \
  "$CREATED" "$EXIST" "$RANGE_START" "$RANGE_END"
