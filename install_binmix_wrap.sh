#!/data/data/com.termux/files/usr/bin/bash
# Обв'язка binmix + 65MB над кожним модулем
CYBRA="$HOME/CYBRA"
BINMIX="$CYBRA/bin/cybra_binmix"
SANDBOX="$CYBRA/sandbox"
LOG="$CYBRA/logs/binmix_wrap.log"
mkdir -p "$CYBRA/logs" "$SANDBOX"/{bin,tmp,keep,trash}
log() { echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $1" >> "$LOG"; }

WRAP_BLOCK='
# ─── BINMIX WRAP (65MB) ───
CYBRA_W="$HOME/CYBRA"
SANDBOX_W="$CYBRA_W/sandbox"
LIMIT_W=$((65 * 1024 * 1024))
mkdir -p "$SANDBOX_W"/{bin,tmp,keep,trash} 2>/dev/null
SIZE_W=$(du -sb "$SANDBOX_W" 2>/dev/null | awk "{print \$1}" || echo 0)
if [ "$SIZE_W" -ge "$LIMIT_W" ]; then
    rm -rf "$SANDBOX_W"/trash/* "$SANDBOX_W"/tmp/* 2>/dev/null
    [ -x "$SANDBOX_W/sandbox_cleanup.sh" ] && "$SANDBOX_W/sandbox_cleanup.sh" >/dev/null 2>&1
fi
BINMIX_W="$CYBRA_W/bin/cybra_binmix"
[ -x "$BINMIX_W" ] && "$BINMIX_W" status >/dev/null 2>&1
# ─── END BINMIX WRAP ───
'

count=0
for f in "$CYBRA"/modules/*/main.sh; do
    [ -f "$f" ] || continue
    # пропускаємо, якщо вже є
    grep -q "BINMIX WRAP" "$f" && continue
    # вставляємо ПІСЛЯ шейбангу (перший рядок)
    python3 - "$f" "$WRAP_BLOCK" <<'PYEOF'
import sys
from pathlib import Path
f = Path(sys.argv[1])
block = sys.argv[2]
lines = f.read_text().split("\n")
# знайти шейбанг
idx = 0
if lines and lines[0].startswith("#!"):
    idx = 1
# вставити блок після шейбангу
lines.insert(idx, block)
f.write_text("\n".join(lines))
PYEOF
    bash -n "$f" 2>/dev/null && count=$((count+1))
done

echo "✅ Обв'язано binmix+65MB: $count модулів"
log "WRAPPED: $count"
