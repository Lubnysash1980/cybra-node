#!/data/data/com.termux/files/usr/bin/bash
while :; do
  redis-cli ping 2>/dev/null | grep -q PONG || {
    pm2 restart redis 2>/dev/null || pm2 start redis-server --name redis -- --daemonize no
  }
  pm2 list 2>/dev/null | grep -q "ai-160.*online" || {
    pm2 start ./cybra_ai_safe.sh --name ai-160 --interpreter bash --max-memory-restart 80M -- 160
  }
  # добити чергу, якщо порожня, а progress < 160
  done=$(redis-cli get cybra:progress:ai_until_done 2>/dev/null | tr -d '"')
  q=$(redis-cli llen cybra:parliament:queue 2>/dev/null)
  if [ "${q:-0}" -eq 0 ] && [ "${done:-0}" -lt 160 ]; then
    for i in $(seq $((done+1)) 160); do
      printf '{"id":"task_%03d","type":"evolution","task":"complete_to_100pct"}' "$i" \
        | redis-cli -x rpush cybra:parliament:queue >/dev/null
    done
  fi
  sleep 30
done
