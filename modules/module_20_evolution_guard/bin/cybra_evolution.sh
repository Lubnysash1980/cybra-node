#!/data/data/com.termux/files/usr/bin/bash
# CYBRA Evolution Guard

ROOT="$HOME/CYBRA"
MODULES="$ROOT/modules"
BASELINE="$ROOT/baseline"
EVO_DIR="$ROOT/evolution"
EVO_LEDGER="$EVO_DIR/evolution_ledger.txt"
EVO_BLOCKED="$EVO_DIR/blocked.log"

TOLERANCE_PERCENT=3
OWNER_MARKER="$ROOT/.owner"

mkdir -p "$EVO_DIR"

# ------------------------------------------------------------
# Логування
# ------------------------------------------------------------

evo_log() {
    printf '%s | %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >> "$EVO_LEDGER"
}

evo_block() {
    printf '%s | %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >> "$EVO_BLOCKED"
}

# ------------------------------------------------------------
# Хеш дерева
# ------------------------------------------------------------

evo_hash_tree() {
    local dir="$1"
    [ ! -d "$dir" ] && { echo "NODIR"; return; }
    (
        cd "$dir" || exit 1
        find . -type f \
            ! -name '*.log' \
            ! -name '*.test.log' \
            ! -name 'test_output.txt' \
            ! -name 'test_output.sha256' \
            ! -name 'SNAPSHOT_SHA256.txt' \
            ! -name '*.bak.*' \
            -print0 2>/dev/null |
        sort -z |
        xargs -0 -r sha256sum 2>/dev/null |
        sha256sum | awk '{print $1}'
    )
}

# ------------------------------------------------------------
# Owner check
# ------------------------------------------------------------

evo_require_owner() {
    if [ ! -f "$OWNER_MARKER" ]; then
        evo_block "OWNER_MARKER_MISSING"
        return 1
    fi
    local owner="$(cat "$OWNER_MARKER" 2>/dev/null)"
    [ -z "$owner" ] && { evo_block "OWNER_MARKER_EMPTY"; return 1; }
    return 0
}

# ------------------------------------------------------------
# 3% tolerance
# ------------------------------------------------------------

evo_within_tolerance() {
    local old="$1"
    local new="$2"
    local tol="${3:-3}"

    [ -z "$old" ] || [ -z "$new" ] && return 1
    [ "$old" = "0" ] && [ "$new" = "0" ] && return 0

    local diff abs
    diff=$(( new - old ))
    abs=$diff
    [ "$diff" -lt 0 ] && abs=$(( -diff ))

    if [ "$old" -eq 0 ]; then
        [ "$abs" -eq 0 ] && return 0
        return 1
    fi

    local allowed=$(( old * tol / 100 ))
    [ "$allowed" -lt 1 ] && allowed=1

    [ "$abs" -le "$allowed" ] && return 0
    return 1
}

# ------------------------------------------------------------
# Перевірка одного модуля
# ------------------------------------------------------------

evo_check_module() {
    local module="$1"
    local dir="$MODULES/$module"

    [ ! -d "$dir" ] && {
        evo_block "MODULE_MISSING: $module"
        return 1
    }

    # --- Tree hash ---
    local old_tree="$(cat "$BASELINE/${module}.tree" 2>/dev/null)"
    local new_tree="$(evo_hash_tree "$dir")"

    # --- Pass/Fail ---
    local old_pass="$(cat "$BASELINE/${module}.pass" 2>/dev/null || echo 0)"
    local old_fail="$(cat "$BASELINE/${module}.fail" 2>/dev/null || echo 0)"
    local new_pass="${2:-$old_pass}"
    local new_fail="${3:-$old_fail}"

    # --- Metric check ---
    if [ "$new_pass" -lt "$old_pass" ]; then
        if evo_within_tolerance "$old_pass" "$new_pass" "$TOLERANCE_PERCENT"; then
            evo_log "OK_TOLERANCE: $module pass $old_pass→$new_pass"
        else
            evo_block "DEGRADATION: $module pass $old_pass→$new_pass"
            return 1
        fi
    fi

    if [ "$new_fail" -gt "$old_fail" ]; then
        evo_block "FAIL_INCREASED: $module $old_fail→$new_fail"
        return 1
    fi

    # --- Security flags (ніколи не можна вимкнути) ---
    if grep -rIq 'AUTO_TRANSACTION=TRUE' "$dir" 2>/dev/null; then
        evo_block "AUTO_TRANSACTION_ENABLED: $module"
        return 1
    fi
    if grep -rIq 'REAL_TRANSACTION_SENT=TRUE' "$dir" 2>/dev/null; then
        evo_block "REAL_TRANSACTION_TRUE: $module"
        return 1
    fi
    if grep -rIq 'GLOBAL_TRUE_100=TRUE' "$dir" 2>/dev/null; then
        evo_block "GLOBAL_TRUE_100_TRUE: $module"
        return 1
    fi

    # --- License recipient check (не можна замінити) ---
    local expected_recipient="0x66434c5501242ccC71b5a39C765892921624B66c"
    if grep -rIq 'LICENSE_.*_RECIPIENT=' "$dir" 2>/dev/null; then
        local bad="$(
            grep -rIh '^LICENSE_.*_RECIPIENT=' "$dir" 2>/dev/null |
            grep -v "$expected_recipient" |
            grep -v 'RECIPIENT=""' |
            head -1
        )"
        if [ -n "$bad" ]; then
            evo_block "LICENSE_RECIPIENT_CHANGED: $module — $bad"
            return 1
        fi
    fi

    # --- License percent check ---
    local bad_pct="$(
        grep -rIh '^LICENSE_[AB]_PERCENT=' "$dir" 2>/dev/null |
        grep -vE '=1$' |
        head -1
    )"
    if [ -n "$bad_pct" ]; then
        evo_block "LICENSE_PERCENT_CHANGED: $module — $bad_pct"
        return 1
    fi

    # --- Tree hash: зміна без approval = блок ---
    if [ -n "$old_tree" ] && [ "$old_tree" != "$new_tree" ]; then
        if [ -f "$EVO_DIR/${module}.approved" ]; then
            local approved="$(cat "$EVO_DIR/${module}.approved")"
            if [ "$approved" = "$new_tree" ]; then
                evo_log "EVOLUTION_APPROVED: $module"
            else
                evo_block "TREE_CHANGED_UNAPPROVED: $module"
                return 1
            fi
        else
            evo_block "TREE_CHANGED_NO_APPROVAL: $module"
            return 1
        fi
    fi

    evo_log "OK: $module"
    return 0
}

# ------------------------------------------------------------
# Перевірка всіх модулів
# ------------------------------------------------------------

evo_check_all() {
    local pass=0
    local fail=0

    for d in "$MODULES"/*/; do
        [ -d "$d" ] || continue
        local m="$(basename "$d")"
        case "$m" in
            @*|.*|_disabled*|evolution|answer_engine|node_modules) continue ;;
        esac

        if evo_check_module "$m"; then
            printf '  [OK] %s\n' "$m"
            pass=$((pass+1))
        else
            printf '  [BLOCKED] %s\n' "$m"
            fail=$((fail+1))
        fi
    done

    printf '\n  PASS: %d\n' "$pass"
    printf '  BLOCKED: %d\n' "$fail"

    [ "$fail" -eq 0 ] && return 0 || return 1
}

# ------------------------------------------------------------
# Approve evolution
# ------------------------------------------------------------

evo_approve() {
    local module="$1"

    evo_require_owner || {
        echo "ERROR: owner not verified"
        return 1
    }

    [ -z "$module" ] && { echo "Usage: evo_approve <module>"; return 1; }
    [ ! -d "$MODULES/$module" ] && { echo "ERROR: module not found"; return 1; }

    local h="$(evo_hash_tree "$MODULES/$module")"
    printf '%s' "$h" > "$EVO_DIR/${module}.approved"
    evo_log "APPROVED_BY_OWNER: $module → $h"
    echo "OK: $module approved"
    echo "Hash: $h"
}

# ------------------------------------------------------------
# Reject evolution
# ------------------------------------------------------------

evo_reject() {
    local module="$1"
    local reason="${2:-manual}"

    rm -f "$EVO_DIR/${module}.approved"
    evo_block "REJECTED: $module reason=$reason"
    echo "REJECTED: $module"
}

# ------------------------------------------------------------
# Snapshot baseline
# ------------------------------------------------------------

evo_snapshot() {
    local out="$EVO_DIR/snapshot_$(date -u +%Y%m%dT%H%M%SZ)"
    mkdir -p "$out"

    for d in "$MODULES"/*/; do
        [ -d "$d" ] || continue
        local m="$(basename "$d")"
        case "$m" in
            @*|.*|_disabled*|evolution|answer_engine|node_modules) continue ;;
        esac

        local h="$(evo_hash_tree "$d")"
        printf '%s %s\n' "$m" "$h" >> "$out/trees.txt"
    done

    LC_ALL=C sort -o "$out/trees.txt" "$out/trees.txt" 2>/dev/null || true

    local snap="$(sha256sum "$out/trees.txt" | awk '{print $1}')"
    printf '%s\n' "$snap" > "$out/snapshot.sha256"

    echo "Snapshot: $out"
    echo "Hash: $snap"
}

# ------------------------------------------------------------
# Freeze on degradation
# ------------------------------------------------------------

evo_freeze() {
    local marker="$EVO_DIR/FROZEN"
    printf '%s | FREEZE_ACTIVATED\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$marker"
    evo_block "FREEZE_ACTIVATED"
    echo "SYSTEM FROZEN — всі операції заблоковані до owner reset"
}

evo_unfreeze() {
    evo_require_owner || {
        echo "ERROR: owner required"
        return 1
    }
    rm -f "$EVO_DIR/FROZEN"
    evo_log "UNFROZEN_BY_OWNER"
    echo "OK: unfrozen"
}

evo_is_frozen() {
    [ -f "$EVO_DIR/FROZEN" ]
}
