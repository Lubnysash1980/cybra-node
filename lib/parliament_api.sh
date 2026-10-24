#!/data/data/com.termux/files/usr/bin/bash
# PARLIAMENT API — для використання в інших скриптах
# usage: source ~/CYBRA/lib/parliament_api.sh
#        parliament_status
#        parliament_submit '{"id":"x","task":"..."}'
#        parliament_wait 60
#        parliament_results 10

: "${CYBRA:=$HOME/CYBRA}"

# статус
parliament_status(){
  local level=$(cat "$CYBRA/state/cybra.level" 2>/dev/null || echo 0)
  local redis=$(redis-cli ping 2>/dev/null | grep -q PONG && echo OK || echo DOWN)
  local q=$(redis-cli llen cybra:parliament:queue 2>/dev/null || echo 0)
  local r=$(redis-cli llen cybra:parliament:results 2>/dev/null || echo 0)
  local f=$(redis-cli llen cybra:parliament:failed 2>/dev/null || echo 0)
  printf '{"level":%s,"redis":"%s","queue":%s,"results":%s,"failed":%s}\n' \
    "$level" "$redis" "$q" "$r" "$f"
}

# надіслати задачу
parliament_submit(){
  local task="$1"
  redis-cli ping 2>/dev/null | grep -q PONG || { echo "redis DOWN"; return 1; }
  printf '%s' "$task" | redis-cli -x rpush cybra:parliament:queue >/dev/null
  echo "$(redis-cli llen cybra:parliament:queue)"
}

# чекати завершення N задач (timeout у секундах)
parliament_wait(){
  local timeout=${1:-60} target=${2:-0}
  local start=$(date +%s)
  while :; do
    local now=$(date +%s); local elapsed=$((now - start))
    [ "$elapsed" -ge "$timeout" ] && { echo "TIMEOUT after ${timeout}s"; return 1; }
    local q=$(redis-cli llen cybra:parliament:queue 2>/dev/null || echo 0)
    [ "$q" -le "$target" ] && { echo "DRAINED (queue=$q)"; return 0; }
    sleep 2
  done
}

# останні N результатів
parliament_results(){
  local n=${1:-10}
  redis-cli lrange cybra:parliament:results -"$n" -1 2>/dev/null
}

# рівень системи
parliament_level(){ cat "$CYBRA/state/cybra.level" 2>/dev/null || echo 0; }

# чи готовий парламент (7/7 + redis + один executor)
parliament_ready(){
  [ "$(parliament_level)" -eq 7 ] \
    && redis-cli ping 2>/dev/null | grep -q PONG \
    && [ "$(ps aux | grep -c '[p]arliament_executor')" -le 2 ]
}

# чекати готовності
parliament_wait_ready(){
  local timeout=${1:-60} start=$(date +%s)
  while ! parliament_ready; do
    [ $(( $(date +%s) - start )) -ge "$timeout" ] && { echo "NOT READY"; return 1; }
    sleep 3
  done
  echo "READY (level=$(parliament_level))"
  return 0
}
