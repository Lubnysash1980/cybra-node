#!/data/data/com.termux/files/usr/bin/bash
# ── BINMIX/EXECUTOR METADATA (auto-added) ──
# module: module_155
# source: github_history  rev=c9950944  when=2026-10-24T12:18:45+03:00
# score: 106  size: 645B  hash: 20a5627b2728
# mixed_at: 2026-10-24T20:29:44.178686+00:00
# ──────────────────────────────────────────

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

echo 'Модуль 155 (Інтегровано AI)'; read -r _