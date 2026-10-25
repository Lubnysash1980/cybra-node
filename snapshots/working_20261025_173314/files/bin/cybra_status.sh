#!/data/data/com.termux/files/usr/bin/bash
echo "========== CYBRA STATUS =========="
echo "Owner: $(cat "$HOME/CYBRA/.owner" 2>/dev/null || echo MISSING)"
echo ""

LATEST_LOG="$(ls -t "$HOME"/CYBRA/logs/mega_hardening_*.log 2>/dev/null | head -1)"

for d in "$HOME"/CYBRA/modules/*/; do
    [ -d "$d" ] || continue
    m=$(basename "$d")
    case "$m" in @*|.*|_disabled*|evolution|answer_engine|node_modules) continue ;; esac

    # Свіжий test log з audit
    tlog="$(ls -t "$HOME"/CYBRA/audit/*_"${m}".test.log 2>/dev/null | head -1)"

    if [ -n "$tlog" ] && [ -f "$tlog" ]; then
        p=$(grep -c '\[PASS\]' "$tlog" 2>/dev/null || true)
        f=$(grep -c '\[FAIL\]' "$tlog" 2>/dev/null || true)
    else
        p=$(cat "$HOME/CYBRA/baseline/${m}.pass" 2>/dev/null || echo 0)
        f=$(cat "$HOME/CYBRA/baseline/${m}.fail" 2>/dev/null || echo 0)
    fi

    t=$(cat "$HOME/CYBRA/baseline/${m}.tree" 2>/dev/null | cut -c1-12 || echo "?")
    printf "  %-45s PASS=%-4s FAIL=%-4s TREE=%s\n" "$m" "$p" "$f" "$t"
done

echo ""
echo "Last report:"
ls -t "$HOME"/CYBRA/audit/*_final_report.env 2>/dev/null | head -1
echo ""
echo "Last hardening log:"

# ─── 7 РІВНІВ СКЛАДНОСТІ ───
LEVEL_FILE="/data/data/com.termux/files/home/CYBRA/state/cybra_status.sh.level"
level_now() { [ -f "$LEVEL_FILE" ] && cat "$LEVEL_FILE" || echo 1; }
level_set() { echo "$1" > "$LEVEL_FILE"; }
level1() { [ -d "$HOME/CYBRA" ] && return 0 || return 1; }
level2() { command -v bash >/dev/null && return 0 || return 1; }
level3() { [ -d "$HOME/CYBRA/modules" ] && return 0 || return 1; }
level4() { [ -d "$HOME/CYBRA/logs" ] && return 0 || return 1; }
level5() { [ -f "$HOME/CYBRA/evo/evo_core.py" ] && return 0 || return 1; }
level6() { [ -d "$HOME/CYBRA/modules" ] && return 0 || return 1; }
level7() { [ -d "$HOME/CYBRA/sandbox" ] && return 0 || return 1; }
run_levels() {
    local cur=$(level_now)
    for i in 1 2 3 4 5 6 7; do
        [ "$i" -lt "$cur" ] && continue
        if "level$i"; then level_set "$i"; else return 0; fi
    done
}
run_levels

echo "$LATEST_LOG"
