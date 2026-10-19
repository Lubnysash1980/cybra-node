#!/data/data/com.termux/files/usr/bin/bash
set -u
module="$1"
[ -z "$module" ] && { echo "Usage: cybra_seal_snapshot.sh <module_name>"; exit 1; }
dir="$HOME/CYBRA/modules/$module"
[ ! -d "$dir" ] && { echo "Module not found: $module"; exit 1; }

snap=""
for s in "$dir/snapshot" "$dir/snapshots"; do
    [ -d "$s" ] && { snap="$s"; break; }
done
[ -z "$snap" ] && { echo "No snapshot dir in $module"; exit 1; }

target="$snap"
sub="$(find "$snap" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null | sort -z | tail -z -n1 | tr -d '\0')"
[ -n "$sub" ] && target="$sub"

echo "Sealing: $target"

(
    cd "$target" || exit 1
    find . -type f \
        ! -name 'final_manifest.sha256' \
        ! -name 'snapshot.sha256' \
        ! -name 'SNAPSHOT_SHA256.txt' \
        ! -name 'SNAPSHOT_DOUBLE_SHA256.txt' \
        ! -name 'double_sha256' \
        ! -name '*.log' \
        -print0 2>/dev/null |
    sort -z |
    xargs -0 -r sha256sum 2>/dev/null
) > "$target/final_manifest.sha256"

count=$(wc -l < "$target/final_manifest.sha256" 2>/dev/null || echo 0)
if [ "$count" -eq 0 ]; then
    printf '# EMPTY_SNAPSHOT module=%s ts=%s\n' "$module" "$(date -u +%Y%m%dT%H%M%SZ)" \
        > "$target/final_manifest.sha256"
    echo "  [OK] empty manifest created (no files yet)"
    exit 0
fi

if (cd "$target" && sha256sum -c final_manifest.sha256 >/dev/null 2>&1); then
    echo "  [OK] final_manifest.sha256 (files=$count)"
else
    echo "  [WARN] verify failed"
    exit 1

# ─── 7 РІВНІВ СКЛАДНОСТІ ───
LEVEL_FILE="/data/data/com.termux/files/home/CYBRA/state/cybra_seal_snapshot.sh.level"
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

fi
