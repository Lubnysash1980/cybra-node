#!/data/data/com.termux/files/usr/bin/bash
# ═══════════════════════════════════════════════════════════
# CYBRA HASH ECOSYSTEM
# Структурована система хешів з snapshot'ами + 3% policy
# ═══════════════════════════════════════════════════════════
set -u
ROOT="$HOME/CYBRA"
HASHES="$ROOT/hashes"
SNAP="$HASHES/snapshots"
MODULES="$ROOT/modules"
BASELINE="$ROOT/baseline"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"

G=$'\033[32m'; Y=$'\033[33m'; R=$'\033[31m'
B=$'\033[1m'; C=$'\033[36m'; Z=$'\033[0m'
ok(){ printf '  %s[✓]%s %s\n' "$G" "$Z" "$*"; }
warn(){ printf '  %s[!]%s %s\n' "$Y" "$Z" "$*"; }
err(){ printf '  %s[✗]%s %s\n' "$R" "$Z" "$*"; }
hdr(){ printf '\n%s═══ %s ═══%s\n' "$B$C" "$*" "$Z"; }

mkdir -p "$HASHES" "$SNAP"

# ─── Hash tree (може бути baseline / actual / snapshot) ───
hash_of() {
    local dir="$1"
    ( cd "$dir" 2>/dev/null || return
      find . -type f \
        ! -name '*.log' ! -name '*.test.log' \
        ! -name 'test_output.*' ! -name 'SNAPSHOT_SHA256.txt' \
        ! -name '*.bak.*' ! -name '*.pid' \
        -print0 2>/dev/null |
      sort -z | xargs -0 -r sha256sum 2>/dev/null |
      sha256sum | awk '{print $1}' )
}

# ─── Layer 1: per-module hash ───
layer1_modules() {
    hdr "LAYER 1 — Module hashes"
    local out="$SNAP/${STAMP}_L1.txt"
    : > "$out"
    local n=0
    for d in "$MODULES"/*/; do
        [ -d "$d" ] || continue
        m="$(basename "$d")"
        case "$m" in @*|.*|_disabled*|evolution|answer_engine|node_modules) continue;; esac
        h="$(hash_of "$d")"
        printf '%s %s\n' "$m" "$h" >> "$out"
        n=$((n+1))
    done
    LC_ALL=C sort -o "$out" "$out"
    L1_HASH="$(sha256sum "$out" | awk '{print $1}')"
    ok "$n modules → L1=$L1_HASH"
}

# ─── Layer 2: baseline hash ───
layer2_baseline() {
    hdr "LAYER 2 — Baseline"
    local out="$SNAP/${STAMP}_L2.txt"
    for t in "$BASELINE"/*.tree; do
        [ -f "$t" ] || continue
        printf '%s %s\n' "$(basename "$t" .tree)" "$(cat "$t")"
    done | LC_ALL=C sort > "$out"
    L2_HASH="$(sha256sum "$out" | awk '{print $1}')"
    ok "baseline → L2=$L2_HASH"
}

# ─── Layer 3: @cybra node ───
layer3_node() {
    hdr "LAYER 3 — @cybra node"
    local node="$ROOT/@cybra"
    local out="$SNAP/${STAMP}_L3.txt"
    if [ -f "$node/index.json" ]; then
        sha256sum "$node/index.json" > "$out"
        L3_HASH="$(awk '{print $1}' "$out")"
        ok "@cybra index → L3=$L3_HASH"
    else
        L3_HASH="NOHASH"
        warn "no @cybra index"
    fi
}

# ─── Layer 4: git state ───
layer4_git() {
    hdr "LAYER 4 — Git state"
    local gitmod="$ROOT/git_module"
    local out="$SNAP/${STAMP}_L4.txt"
    if [ -d "$gitmod/.git" ]; then
        (cd "$gitmod" && {
            printf 'commit=%s\n' "$(git rev-parse HEAD 2>/dev/null)"
            printf 'branch=%s\n' "$(git branch --show-current 2>/dev/null)"
            printf 'remote=%s\n' "$(git remote get-url origin 2>/dev/null)"
            printf 'status=%s\n' "$(git status --porcelain 2>/dev/null | wc -l)"
        }) > "$out"
        L4_HASH="$(sha256sum "$out" | awk '{print $1}')"
        ok "git → L4=$L4_HASH"
    else
        L4_HASH="NOHASH"
        warn "no git"
    fi
}

# ─── Layer 3.5: AI Task Bar ───
layer3_5_ai() {
    hdr "LAYER 3.5 — AI Task Bar"
    local out="$SNAP/${STAMP}_L35.txt"
    local ai1="$ROOT/CYBRA_AI_TASK_BAR.sh"
    local ai2=""
    for p in "$ROOT/ai/cybra_local_ai.sh" \
             "$ROOT/modules/module_19_contract_tui_menu/bin/cybra_local_ai.sh"; do
        [ -f "$p" ] && { ai2="$p"; break; }
    done

    if [ -f "$ai1" ] && [ -n "$ai2" ]; then
        {
            printf 'task_bar=%s\n' "$(sha256sum "$ai1" | awk '{print $1}')"
            printf 'local_ai=%s\n' "$(sha256sum "$ai2" | awk '{print $1}')"
        } > "$out"
        L35_HASH="$(sha256sum "$out" | awk '{print $1}')"
        ok "AI → L3.5=$L35_HASH"
    else
        L35_HASH="NOHASH"
        warn "AI files missing"
    fi
}

# ─── Layer 5: combined ULTRA hash ───
layer5_ultra() {
    hdr "LAYER 5 — ULTRA (all layers)"
    local out="$SNAP/${STAMP}_L5.txt"
    {
        printf 'L1=%s\n' "$L1_HASH"
        printf 'L2=%s\n' "$L2_HASH"
        printf 'L3=%s\n' "$L3_HASH"
        printf 'L3_5=%s\n' "$L35_HASH"
        printf 'L4=%s\n' "$L4_HASH"
    } > "$out"
    ULTRA="$(sha256sum "$out" | awk '{print $1}')"
    ok "ULTRA=$ULTRA"

    # Global manifest
    cat > "$SNAP/${STAMP}.env" <<EOF
STAMP=$STAMP
L1_MODULES=$L1_HASH
L2_BASELINE=$L2_HASH
L3_NODE=$L3_HASH
L3_5_AI=$L35_HASH
L4_GIT=$L4_HASH
ULTRA=$ULTRA
EOF

    # Human-readable
    {
        printf '═══ CYBRA HASH SNAPSHOT ═══\n'
        printf 'Stamp: %s\n\n' "$STAMP"
        printf 'L1 Modules:  %s\n' "$L1_HASH"
        printf 'L2 Baseline: %s\n' "$L2_HASH"
        printf 'L3 @cybra:   %s\n' "$L3_HASH"
        printf 'L3.5 AI:     %s\n' "$L35_HASH"
        printf 'L4 Git:      %s\n' "$L4_HASH"
        printf '────────────────────────────────\n'
        printf 'ULTRA:       %s\n' "$ULTRA"
    } > "$SNAP/${STAMP}.report"

    cat "$SNAP/${STAMP}.report"
}

# ─── 3% policy check ───
check_3pct() {
    hdr "3% POLICY"
    # Останній snapshot
    local prev="$(ls -t "$SNAP"/*.env 2>/dev/null | tail -2 | head -1)"
    [ -z "$prev" ] && { warn "no previous snapshot"; return 0; }

    local prev_ultra="$(grep '^ULTRA=' "$prev" | cut -d= -f2)"
    printf '  prev: %s\n' "${prev_ultra:0:16}..."
    printf '  cur:  %s\n' "${ULTRA:0:16}..."

    # 3% = різниця в hex не має сенсу, тому рахуємо "0 = збіг, 1 = різниця"
    # Реальний 3% — це метрики pass/fail, тут перевіряємо тільки стабільність
    if [ "$prev_ultra" = "$ULTRA" ]; then
        ok "UNCHANGED (0% drift)"
    else
        # Показати що змінилось
        printf '  changed layers:\n'
        local pl1="$(grep '^L1_MODULES=' "$prev" | cut -d= -f2)"
        local pl2="$(grep '^L2_BASELINE=' "$prev" | cut -d= -f2)"
        [ "$pl1" != "$L1_HASH" ] && printf '    L1 modules CHANGED\n' || printf '    L1 modules stable\n'
        [ "$pl2" != "$L2_HASH" ] && printf '    L2 baseline CHANGED\n' || printf '    L2 baseline stable\n'
        printf '  (3%% tolerance: apply to pass/fail metrics, not tree hashes)\n'
    fi
}

# ─── Cleanup старих snapshots ───
cleanup() {
    ls -t "$SNAP"/*.env 2>/dev/null | tail -n +51 | xargs -r rm -f
    ls -t "$SNAP"/*_L1.txt 2>/dev/null | tail -n +51 | xargs -r rm -f
    ls -t "$SNAP"/*_L2.txt 2>/dev/null | tail -n +51 | xargs -r rm -f
    ls -t "$SNAP"/*_L3.txt 2>/dev/null | tail -n +51 | xargs -r rm -f
    ls -t "$SNAP"/*_L4.txt 2>/dev/null | tail -n +51 | xargs -r rm -f
    ls -t "$SNAP"/*_L5.txt 2>/dev/null | tail -n +51 | xargs -r rm -f
    ls -t "$SNAP"/*.report 2>/dev/null | tail -n +51 | xargs -r rm -f
}

# ─── Push у GitHub ───
push_hashes() {
    hdr "PUSH HASHES"
    local gitmod="$ROOT/git_module"
    [ -d "$gitmod/.git" ] || { err "no git"; return 1; }

    mkdir -p "$gitmod/hashes"
    cp -r "$SNAP"/*.env "$gitmod/hashes/" 2>/dev/null
    cp -r "$SNAP"/*.report "$gitmod/hashes/" 2>/dev/null
    cp "$SNAP/${STAMP}_L1.txt" "$gitmod/hashes/" 2>/dev/null

    cd "$gitmod" || return 1
    git add hashes/ 2>/dev/null

    if [ -z "$(git status --porcelain hashes/ 2>/dev/null)" ]; then
        ok "no changes"
        return 0
    fi

    git commit -m "hash snapshot $STAMP ultra=${ULTRA:0:12}" 2>&1 | tail -1

    local out="$(git push origin main 2>&1)"
    if printf '%s' "$out" | grep -qE 'main -> main|Everything up-to-date'; then
        ok "PUSHED"
    else
        err "push failed"
        printf '%s\n' "$out" | tail -3 | sed 's/^/    /'
        return 1
    fi
}

# ─── Повний цикл ───
run_all() {
    L1_HASH=; L2_HASH=; L3_HASH=; L35_HASH=; L4_HASH=; ULTRA=
    layer1_modules
    layer2_baseline
    layer3_node
    layer3_5_ai
    layer4_git
    layer5_ultra
    check_3pct
    cleanup
    push_hashes
}

# ─── CLI ───
case "${1:-run}" in
    run|r|"")   run_all ;;
    layers|l)   L1_HASH=; L2_HASH=; L3_HASH=; L35_HASH=; L4_HASH=; ULTRA=
                layer1_modules; layer2_baseline; layer3_node; layer4_git; layer5_ultra ;;
    3pct)       check_3pct ;;
    push|p)     push_hashes ;;
    list)       ls -t "$SNAP"/*.report 2>/dev/null | head -5 | while read f; do
                    echo "── $(basename "$f") ──"
                    cat "$f" | sed 's/^/  /'
                    echo ""
                done ;;
    cleanup|c)  cleanup; ok "cleaned" ;;
    *)
        echo "Usage: cybra_hash [run|layers|3pct|push|list|cleanup]"
        ;;
esac
