#!/data/data/com.termux/files/usr/bin/bash
# ── AUTOBUILD ── module 13 src=fallback at=2026-10-30T15:37:45.983271+00:00
# module_013 — Dual Backend  (autobuild fallback)
set -u
CYBRA="$HOME/CYBRA"; cd "$CYBRA" 2>/dev/null || exit 1
echo "════ [13] Dual Backend ════════"
echo "── git ──"
git --no-pager log -1 --format='  %h %s (%cr)' 2>/dev/null || echo "  no git"
echo "  changes: $(git status --porcelain 2>/dev/null | wc -l)"
echo "── redis ──"
redis-cli ping 2>/dev/null | sed 's/^/  /' || echo "  DOWN"
echo "  keys: $(redis-cli dbsize 2>/dev/null || echo 0)"
echo "── system ──"
free -m 2>/dev/null | awk '/Mem:/{printf "  RAM: %d/%d MB\n", $3, $2}'
df -h /data 2>/dev/null | awk 'NR==2{print "  disk: "$5" used"}'
echo "── pm2 ──"
pm2 jlist 2>/dev/null | python3 -c "import sys,json;d=json.load(sys.stdin);print(f'  online: {sum(1 for p in d if p[\"pm2_env\"][\"status\"]==\"online\")}/{len(d)}')" 2>/dev/null || echo "  n/a"
echo "── log ──"
tail -3 logs/module_013*.log 2>/dev/null | sed 's/^/  /' || echo "  (no log)"
read -r -p "Enter..." _
