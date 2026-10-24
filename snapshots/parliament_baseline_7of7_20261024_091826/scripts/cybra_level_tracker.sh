#!/data/data/com.termux/files/usr/bin/bash
# CYBRA LEVEL TRACKER — піднімає систему 1→7 рівнів
# L1 базовий → L2 середовище → L3 ядро → L4 health → L5 EVO → L6 контракти → L7 повна
set -u
CYBRA="$HOME/CYBRA"; cd "$CYBRA" || exit 1
LEVEL_FILE="$CYBRA/state/cybra.level"; mkdir -p "$CYBRA/state" "$CYBRA/logs"
LOG="$CYBRA/logs/level_tracker.log"
INTERVAL=${1:-30}

log(){ echo "[$(date -u +%FT%TZ)] $*" | tee -a "$LOG"; }
lvl_now(){ [ -f "$LEVEL_FILE" ] && cat "$LEVEL_FILE" || echo 0; }
lvl_set(){ echo "$1" > "$LEVEL_FILE"; }

# ─── Перевірки рівнів ───
check_L1(){  # базовий: redis + тека
  redis-cli ping 2>/dev/null | grep -q PONG
}
check_L2(){  # середовище: python3, node, ключові файли
  command -v python3 >/dev/null && command -v node >/dev/null \
    && [ -f cybra_ai_until_done.sh ] && [ -d modules ]
}
check_L3(){  # ядро: парламентський демон онлайн
  pm2 jlist 2>/dev/null | python3 -c "
import sys,json
d=[p['pm2_env']['status'] for p in json.load(sys.stdin) if p['name']=='parliament']
sys.exit(0 if 'online' in d else 1)"
}
check_L4(){  # health: без fork bomb, RAM < 85%
  local execs=$(ps aux 2>/dev/null | grep -c '[p]arliament_executor')
  local r=$(free -m 2>/dev/null | awk '/Mem:/{printf "%d",$3/$2*100}')
  [ "$execs" -le 2 ] && [ "${r:-0}" -lt 85 ]
}
check_L5(){  # EVO: структура evo/ і останні результати
  [ -d evo ] && [ "$(ls -1 evo 2>/dev/null | wc -l)" -gt 0 ]
}
check_L6(){  # контракти: module_19 + results
  [ -d modules/module_19_contract_tui_menu ] \
    && [ "$(redis-cli llen cybra:parliament:results 2>/dev/null || echo 0)" -gt 0 ]
}
check_L7(){  # повна екосистема: модулів > 200, парламент + runtime + evo живі
  local mods=$(ls -1 modules 2>/dev/null | wc -l)
  local alive=$(pm2 jlist 2>/dev/null | python3 -c "
import sys,json
d=json.load(sys.stdin)
need={'redis','parliament','runtime'}
have={p['name'] for p in d if p['pm2_env']['status']=='online'}
print('ok' if need.issubset(have) else 'no')")
  [ "$mods" -gt 200 ] && [ "$alive" = "ok" ]
}

# ─── Сходження ───
ascend(){
  local cur=$(lvl_now)
  local new=$cur
  local stuck_at=""
  for i in 1 2 3 4 5 6 7; do
    if "check_L$i"; then
      new=$i
    else
      stuck_at="L$i"
      break
    fi
  done

  if [ "$new" -gt "$cur" ]; then
    log "⬆ $cur/7 → $new/7"
    lvl_set "$new"
    redis-cli set cybra:level "$new" >/dev/null
  elif [ "$new" -lt "$cur" ]; then
    log "⬇ $cur/7 → $new/7 (застряг на ${stuck_at:-?})"
    lvl_set "$new"
    redis-cli set cybra:level "$new" >/dev/null
  else
    [ -n "$stuck_at" ] && log "= ${cur}/7 (стіна: $stuck_at)"
    [ -z "$stuck_at" ] && log "= ${cur}/7 (OK)"
  fi
}

log "═══ LEVEL TRACKER START (interval=${INTERVAL}s) ═══"
while :; do
  ascend
  sleep "$INTERVAL"
done
