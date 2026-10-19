#!/data/data/com.termux/files/usr/bin/bash
set -u
module="$1"
[ -z "$module" ] && { echo "Usage: cybra_approve_evolution <module_name>"; exit 1; }
dir="$HOME/CYBRA/modules/$module"
[ ! -d "$dir" ] && { echo "Module not found: $module"; exit 1; }

hash="$(
    cd "$dir" || exit 1
    find . -type f \
        ! -name '*.log' \
        ! -name '*.test.log' \
        ! -name 'test_output.txt' \
        ! -name 'test_output.sha256' \
        ! -name 'SNAPSHOT_SHA256.txt' \
        -print0 |
    sort -z |
    xargs -0 -r sha256sum |
    sha256sum | awk '{print $1}'
)"

mkdir -p "$HOME/CYBRA/evolution"
printf '%s' "$hash" > "$HOME/CYBRA/evolution/${module}.approved"
echo "Evolution approved for $module"

# ─── 7 РІВНІВ СКЛАДНОСТІ ───
LEVEL_FILE="/data/data/com.termux/files/home/CYBRA/state/cybra_approve_evolution.sh.level"
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

echo "Hash: $hash"
