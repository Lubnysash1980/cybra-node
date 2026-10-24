#!/data/data/com.termux/files/usr/bin/bash
# CONTRACT → PARLIAMENT BRIDGE
# Використовується з TUI меню або з інших скриптів
# usage:
#   source lib/contract_parliament_bridge.sh
#   contract_submit_audit              # повний аудит
#   contract_submit_task <action> <payload>
set -u
source "$HOME/CYBRA/lib/parliament_api.sh"

CYBRA="$HOME/CYBRA"

# ─── Подати задачу на аудит усіх контрактів ───
contract_submit_audit(){
  local scope="${1:-all}"
  parliament_submit "{
    \"id\":\"c_audit_$(date +%s)\",
    \"type\":\"contract_audit\",
    \"scope\":\"$scope\",
    \"checks\":[\"validity\",\"links\",\"license\",\"pii\",\"signature\",\"hash\"]
  }"
}

# ─── Подати конкретну дію з контрактом ───
contract_submit_action(){
  local action="$1" cid="$2" payload="${3:-{}}"
  parliament_submit "{
    \"id\":\"c_${action}_${cid}_$(date +%s)\",
    \"type\":\"contract_action\",
    \"action\":\"$action\",
    \"contract_id\":\"$cid\",
    \"payload\":$payload
  }"
}

# ─── Подати «доопрацювання до ідеалу» для одного контракту ───
contract_submit_idealize(){
  local cid="$1"
  parliament_submit "{
    \"id\":\"c_ideal_${cid}_$(date +%s)\",
    \"type\":\"contract_idealize\",
    \"contract_id\":\"$cid\",
    \"requirements\":[
      \"all_links_verified\",
      \"license_1pct_1pct_1pct_ok\",
      \"pii_masked\",
      \"invoice_signed\",
      \"hash_valid\",
      \"metadata_complete\"
    ]
  }"
}

# ─── Пакет: «доробити всі контракти до ідеалу» ───
contract_idealize_all(){
  local contracts="${1:-}"
  # якщо не передано — спробуємо витягнути з registry або redis
  if [ -z "$contracts" ]; then
    if [ -d "$CYBRA/registry" ]; then
      contracts=$(ls "$CYBRA/registry"/*.json 2>/dev/null | sed 's#.*/##;s#\.json##')
    fi
    if [ -z "$contracts" ]; then
      contracts=$(redis-cli smembers cybra:contracts 2>/dev/null)
    fi
  fi

  local n=0
  for cid in $contracts; do
    [ -z "$cid" ] && continue
    contract_submit_idealize "$cid" >/dev/null
    n=$((n+1))
  done
  echo "$n"
}
