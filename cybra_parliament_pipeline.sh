#!/data/data/com.termux/files/usr/bin/bash
# PARLIAMENT PIPELINE — 160 задач через Кіберпарламент + авоснапшот
set -u
source "$HOME/CYBRA/lib/parliament_api.sh"
CYBRA="$HOME/CYBRA"; cd "$CYBRA" || exit 1
N=${1:-160}
NAME="${2:-pipeline_${N}}"

echo "═══ PIPELINE: $N задач через Кіберпарламент ═══"
parliament_wait_ready 30 || { echo "❌ парламент не готовий"; exit 1; }

before=$(parliament_status)
echo "before: $before"

echo "→ подаю $N задач"
for i in $(seq 1 "$N"); do
  parliament_submit "{\"id\":\"pipe_$(printf '%03d' $i)\",\"type\":\"evolution\",\"task\":\"reach_100\",\"src\":\"pipeline\"}" >/dev/null
done
echo "queue: $(redis-cli llen cybra:parliament:queue)"

echo "→ чекаю обробки (макс 10 хв)"
timeout 600 bash -c '
  while [ "$(redis-cli llen cybra:parliament:queue 2>/dev/null || echo 0)" -gt 0 ]; do
    sleep 5
  done
' && echo "✅ DRAINED" || echo "⏱ TIMEOUT"

after=$(parliament_status)
echo "after:  $after"

echo "→ снапшот результату"
"$CYBRA/cybra_parliament_snapshot.sh" "$NAME" 2>&1 | tail -5
