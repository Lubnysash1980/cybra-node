#!/data/data/com.termux/files/usr/bin/bash
# CYBRA GUARDIAN — Module 35

GUARD_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GUARD_VAULT="$GUARD_ROOT/vault"
GUARD_DATA="$GUARD_ROOT/data"
GUARD_EV="$GUARD_ROOT/evidence"
GUARD_REC="$GUARD_ROOT/recovery"

mkdir -p "$GUARD_VAULT" "$GUARD_DATA" "$GUARD_EV" "$GUARD_REC"

# ─── Colors ───
if [ -t 1 ]; then
    GR=$'\033[32m'; RD=$'\033[31m'; YL=$'\033[33m'
    CY=$'\033[36m'; BD=$'\033[1m'; Z=$'\033[0m'
else
    GR=""; RD=""; YL=""; CY=""; BD=""; Z=""
fi

# ═══════════════════════════════════════════════════════════
# IDENTITY VAULT
# ═══════════════════════════════════════════════════════════

# --- Hash PII ---
gd_hash() {
    local value="$1"
    local salt="${IDENTITY_SALT:-CYBRA_GUARDIAN_v1}"
    printf '%s|%s' "$salt" "$value" | sha256sum | awk '{print $1}'
}

gd_hash_short() {
    local value="$1"
    local h="$(gd_hash "$value")"
    echo "${h:0:16}"
}

# --- Device fingerprint ---
gd_device_fingerprint() {
    local model serial android_id
    model="$(getprop ro.product.model 2>/dev/null || echo unknown)"
    serial="$(getprop ro.serialno 2>/dev/null || echo unknown)"
    android_id="$(settings get secure android_id 2>/dev/null || echo unknown)"
    
    local raw="${model}|${serial}|${android_id}"
    printf '%s' "$raw" | sha256sum | awk '{print $1}'
}

gd_device_info() {
    printf 'Model:    %s\n' "$(getprop ro.product.model 2>/dev/null || echo unknown)"
    printf 'Brand:    %s\n' "$(getprop ro.product.brand 2>/dev/null || echo unknown)"
    printf 'Android:  %s\n' "$(getprop ro.build.version.release 2>/dev/null || echo unknown)"
    printf 'SDK:      %s\n' "$(getprop ro.build.version.sdk 2>/dev/null || echo unknown)"
    printf 'Arch:     %s\n' "$(uname -m)"
    printf 'Fingerprint: %s\n' "$(gd_device_fingerprint)"
}

# --- Register identity ---
gd_register() {
    local name="$1" id_num="$2" wallet="$3" bio="${4:-none}"

    [ -z "$name" ] || [ -z "$id_num" ] || [ -z "$wallet" ] && {
        echo "ERR: name + id_num + wallet required"; return 1
    }

    local id_file="$GUARD_VAULT/identity.env"
    local name_hash="$(gd_hash "$name")"
    local id_hash="$(gd_hash "$id_num")"
    local wallet_hash="$(gd_hash "$wallet")"
    local bio_hash="$(gd_hash "$bio")"
    local dev_fp="$(gd_device_fingerprint)"
    local now="$(date -u +%FT%TZ)"

    cat > "$id_file" <<ID
# CYBRA GUARDIAN IDENTITY VAULT
# Raw PII is NOT stored — only salted SHA-256 hashes

REGISTERED_AT=$now
IDENTITY_ID=$(head -c 8 /dev/urandom | od -An -tx1 | tr -d ' \n')

NAME_HASH=$name_hash
ID_HASH=$id_hash
WALLET_HASH=$wallet_hash
BIOMETRIC_HASH=$bio_hash
DEVICE_FP=$dev_fp

IDENTITY_SALT=$IDENTITY_SALT
HASH_ALGO=sha256
ID

    chmod 600 "$id_file"

    # Registry (append-only)
    printf '%s | %s | %s | %s\n' \
        "$now" "$(gd_hash_short "$name")" "$(gd_hash_short "$id_num")" "$dev_fp" \
        >> "$GUARD_VAULT/registry.log"

    echo "OK: identity registered"
    echo "  Name hash:      ${name_hash:0:16}..."
    echo "  ID hash:        ${id_hash:0:16}..."
    echo "  Wallet hash:    ${wallet_hash:0:16}..."
    echo "  Device FP:      ${dev_fp:0:16}..."
    echo "  Biometric:      ${bio_hash:0:16}..."
}

# --- Verify identity ---
gd_verify() {
    local name="$1" id_num="$2" wallet="$3" bio="${4:-none}"
    local id_file="$GUARD_VAULT/identity.env"
    [ ! -f "$id_file" ] && { echo "ERR: no identity"; return 1; }

    source "$id_file"

    local name_ok id_ok wallet_ok bio_ok
    [ "$(gd_hash "$name")" = "$NAME_HASH" ] && name_ok=1 || name_ok=0
    [ "$(gd_hash "$id_num")" = "$ID_HASH" ] && id_ok=1 || id_ok=0
    [ "$(gd_hash "$wallet")" = "$WALLET_HASH" ] && wallet_ok=1 || wallet_ok=0
    [ "$(gd_hash "$bio")" = "$BIOMETRIC_HASH" ] && bio_ok=1 || bio_ok=0

    if [ "$name_ok" = "1" ] && [ "$id_ok" = "1" ] && [ "$wallet_ok" = "1" ]; then
        echo "OK: identity verified"
        return 0
    fi

    echo "FAIL: identity mismatch"
    [ "$name_ok" = "0" ] && echo "  name mismatch"
    [ "$id_ok" = "0" ] && echo "  id mismatch"
    [ "$wallet_ok" = "0" ] && echo "  wallet mismatch"
    return 1
}

# --- Show identity (masked) ---
gd_show_identity() {
    local id_file="$GUARD_VAULT/identity.env"
    [ ! -f "$id_file" ] && { echo "(identity not registered)"; return 1; }

    source "$id_file"

    printf '%s═══ GUARDIAN IDENTITY ═══%s\n' "$BD" "$Z"
    printf 'Registered:  %s\n' "$REGISTERED_AT"
    printf 'Identity ID: %s\n' "$IDENTITY_ID"
    printf '\n'
    printf 'Name hash:   %s...\n' "${NAME_HASH:0:32}"
    printf 'ID hash:     %s...\n' "${ID_HASH:0:32}"
    printf 'Wallet hash: %s...\n' "${WALLET_HASH:0:32}"
    printf 'Bio hash:    %s...\n' "${BIOMETRIC_HASH:0:32}"
    printf 'Device FP:   %s...\n' "${DEVICE_FP:0:32}"
    printf '\n%sRaw PII НЕ зберігається%s\n' "$YL" "$Z"
}

# ═══════════════════════════════════════════════════════════
# 100% STATE MONITOR
# ═══════════════════════════════════════════════════════════

gd_check_state() {
    local total=0 ok=0
    local report="$GUARD_EV/state_report.txt"
    : > "$report"

    {
        printf '═══ CYBRA GUARDIAN — 100%% STATE CHECK ═══\n'
        printf 'Time: %s\n\n' "$(date -u +%FT%TZ)"
    } >> "$report"

    # ─── 1. Directories ───
    for d in "$HOME/CYBRA" "$HOME/CYBRA/modules" "$HOME/CYBRA/baseline" \
             "$HOME/CYBRA/evolution" "$HOME/CYBRA/audit"; do
        total=$((total+1))
        if [ -d "$d" ]; then
            printf '  [OK]   dir: %s\n' "$(basename "$d")" >> "$report"
            ok=$((ok+1))
        else
            printf '  [FAIL] dir: %s\n' "$d" >> "$report"
        fi
    done

    # ─── 2. Modules ───
    local mod_count=0
    for d in "$HOME/CYBRA/modules"/*/; do
        [ -d "$d" ] || continue
        local m="$(basename "$d")"
        case "$m" in @*|.*|_disabled*|evolution|answer_engine|node_modules) continue ;; esac
        mod_count=$((mod_count+1))
        total=$((total+1))

        if [ -f "$d/tests/run_tests.sh" ] || [ -f "$d/tests/test_module_*.sh" ]; then
            printf '  [OK]   module: %s\n' "$m" >> "$report"
            ok=$((ok+1))
        else
            printf '  [WARN] module: %s (no tests)\n' "$m" >> "$report"
        fi
    done

    # ─── 3. Key files ───
    for f in \
        "$HOME/CYBRA/cybra_mega_hardening.sh" \
        "$HOME/CYBRA/.owner" \
        "$HOME/CYBRA/CYBRA_AI_TASK_BAR.sh"
    do
        total=$((total+1))
        if [ -f "$f" ]; then
            printf '  [OK]   file: %s\n' "$(basename "$f")" >> "$report"
            ok=$((ok+1))
        else
            printf '  [FAIL] file: %s\n' "$f" >> "$report"
        fi
    done

    # ─── 4. Git repo ───
    total=$((total+1))
    if [ -d "$HOME/CYBRA/git_module/.git" ]; then
        printf '  [OK]   git repo\n' >> "$report"
        ok=$((ok+1))
    else
        printf '  [FAIL] git repo\n' >> "$report"
    fi

    # ─── 5. Identity ───
    total=$((total+1))
    if [ -f "$GUARD_VAULT/identity.env" ]; then
        printf '  [OK]   identity vault\n' >> "$report"
        ok=$((ok+1))
    else
        printf '  [WARN] identity vault (не зареєстровано)\n' >> "$report"
    fi

    local pct=$((ok * 100 / total))

    {
        printf '\n--- SUMMARY ---\n'
        printf 'Total: %s\n' "$total"
        printf 'OK:    %s\n' "$ok"
        printf 'Pct:   %s%%\n' "$pct"
    } >> "$report"

    cat "$report"

    # Save percentage
    printf '%s' "$pct" > "$GUARD_EV/state_pct.txt"
    printf '%s' "$(date -u +%FT%TZ)" > "$GUARD_EV/state_time.txt"

    if [ "$pct" -eq 100 ]; then
        return 0
    else
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════
# AUTO-RECOVERY
# ═══════════════════════════════════════════════════════════

gd_recovery_snapshot() {
    local stamp="$(date -u +%Y%m%dT%H%M%SZ)"
    local file="$GUARD_REC/snapshot_${stamp}.tar.gz"

    tar -czf "$file" \
        -C "$HOME" \
        --exclude='CYBRA/backups' \
        --exclude='CYBRA/**/node_modules' \
        --exclude='CYBRA/git_module/.git' \
        --exclude='CYBRA/logs' \
        CYBRA 2>/dev/null

    sha256sum "$file" > "${file}.sha256"
    printf '%s\n' "$file" >> "$GUARD_REC/snapshots.list"

    # Ротація — 10 останніх
    ls -t "$GUARD_REC"/snapshot_*.tar.gz 2>/dev/null | tail -n +11 | xargs -r rm -f
    ls -t "$GUARD_REC"/snapshot_*.tar.gz.sha256 2>/dev/null | tail -n +11 | xargs -r rm -f

    echo "OK: $file"
    du -h "$file"
}

gd_recovery_from_git() {
    local repo="$HOME/CYBRA/git_module"
    [ ! -d "$repo/.git" ] && { echo "ERR: git repo not found"; return 1; }

    cd "$repo" || return 1

    echo "→ Fetching from origin..."
    git fetch --all 2>&1 | tail -2

    local remote_branch="origin/main"
    if ! git rev-parse --verify "$remote_branch" >/dev/null 2>&1; then
        remote_branch="origin/master"
    fi

    echo "→ Checking for differences..."
    local local_rev="$(git rev-parse HEAD 2>/dev/null)"
    local remote_rev="$(git rev-parse "$remote_branch" 2>/dev/null)"

    if [ "$local_rev" = "$remote_rev" ]; then
        echo "OK: локальний стан співпадає з remote"
        return 0
    fi

    echo ""
    echo "Local:  ${local_rev:0:12}"
    echo "Remote: ${remote_rev:0:12}"
    echo ""

    printf 'Відновити з remote? [y/N]: '
    read -r ans
    if [ "$ans" = "y" ] || [ "$ans" = "Y" ]; then
        git stash push -m "guardian_backup_$(date +%s)" 2>/dev/null || true
        git reset --hard "$remote_branch"
        echo "OK: відновлено з $remote_branch"
    fi

    cd "$HOME" || true
}

gd_recovery_from_snapshot() {
    local list="$GUARD_REC/snapshots.list"
    [ ! -f "$list" ] && { echo "ERR: no snapshots"; return 1; }

    printf '%sДоступні snapshots:%s\n' "$BD" "$Z"
    local i=1
    while IFS= read -r f; do
        [ -f "$f" ] || continue
        printf '  [%s] %s\n' "$i" "$(basename "$f")"
        i=$((i+1))
    done < "$list"

    printf '\nВибір (1-%s): ' "$((i-1))"
    read -r choice

    local target
    target="$(sed -n "${choice}p" "$list")"
    [ ! -f "$target" ] && { echo "ERR: invalid choice"; return 1; }

    echo "→ Verifying..."
    sha256sum -c "${target}.sha256" 2>&1 | tail -2

    local restore_dir="$HOME/CYBRA_RESTORE_$(date +%s)"
    mkdir -p "$restore_dir"
    echo "→ Extracting to $restore_dir"
    tar -xzf "$target" -C "$restore_dir"
    echo "OK: extracted"
    echo ""
    echo "Щоб замінити — вручну:"
    echo "  mv ~/CYBRA ~/CYBRA.bak"
    echo "  mv $restore_dir/CYBRA ~/CYBRA"
}

gd_auto_recover() {
    echo "→ Guardian auto-recovery..."
    
    local pct="$(cat "$GUARD_EV/state_pct.txt" 2>/dev/null || echo 0)"
    
    if [ "$pct" -eq 100 ]; then
        echo "  [OK] state = 100%, recovery not needed"
        return 0
    fi

    echo "  [WARN] state = ${pct}%, attempting recovery..."

    # 1. Self-heal
    if [ -x "$HOME/CYBRA/modules/module_19_contract_tui_menu/bin/cybra_self_heal.sh" ]; then
        echo "  → self-heal..."
        bash "$HOME/CYBRA/modules/module_19_contract_tui_menu/bin/cybra_self_heal.sh" 2>&1 | tail -3
    fi

    # 2. Fix missing dirs
    for d in "$HOME/CYBRA" "$HOME/CYBRA/modules" "$HOME/CYBRA/baseline" \
             "$HOME/CYBRA/evolution" "$HOME/CYBRA/audit"; do
        [ ! -d "$d" ] && mkdir -p "$d" && echo "  → created $(basename "$d")"
    done

    # 3. Owner marker
    [ ! -f "$HOME/CYBRA/.owner" ] && {
        printf 'CYBRA_OWNER_%s\n' "$(date -u +%Y%m%dT%H%M%SZ)" > "$HOME/CYBRA/.owner"
        chmod 600 "$HOME/CYBRA/.owner"
        echo "  → owner marker restored"
    }

    # 4. Re-check
    gd_check_state > /dev/null 2>&1
    local new_pct="$(cat "$GUARD_EV/state_pct.txt" 2>/dev/null || echo 0)"
    echo "  After recovery: ${new_pct}%"

    if [ "$new_pct" -eq 100 ]; then
        echo "  [OK] recovered to 100%"
        return 0
    else
        echo "  [WARN] still ${new_pct}% — спробуй manual recovery"
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════
# ACTION LOG
# ═══════════════════════════════════════════════════════════

gd_log() {
    local action="$1" target="$2" status="$3"
    local log="$GUARD_EV/actions.log"
    local ts="$(date -u +%FT%TZ)"
    local dev="$(gd_device_fingerprint | head -c 16)"
    local prev="$(tail -1 "$log" 2>/dev/null | awk -F'|' '{print $NF}' | tr -d ' ')"
    [ -z "$prev" ] && prev="GENESIS"

    local payload="${ts}|${action}|${target}|${status}|${dev}|${prev}"
    local hash="$(printf '%s' "$payload" | sha256sum | awk '{print $1}')"
    printf '%s|%s\n' "$payload" "$hash" >> "$log"
}

gd_log_verify() {
    local log="$GUARD_EV/actions.log"
    [ ! -f "$log" ] && { echo "ERR: no log"; return 1; }

    local prev="GENESIS" line_no=0 ok=1
    while IFS='|' read -r ts action target status dev phash hash; do
        line_no=$((line_no+1))
        local payload="${ts}|${action}|${target}|${status}|${dev}|${prev}"
        local computed="$(printf '%s' "$payload" | sha256sum | awk '{print $1}')"
        if [ "$computed" != "$hash" ]; then
            echo "BROKEN at line $line_no"
            ok=0
            break
        fi
        prev="$hash"
    done < "$log"

    [ "$ok" -eq 1 ] && echo "OK: $line_no entries verified" || echo "BROKEN"
}

# ═══════════════════════════════════════════════════════════
# GUARDIAN PUSH AFTER CONTRACT
# ═══════════════════════════════════════════════════════════

gd_after_contract() {
    local cid="$1"

    gd_log "contract_created" "$cid" "OK"

    echo "→ Guardian: pushing to git..."
    cd "$HOME/CYBRA/git_module" 2>/dev/null && {
        # Копіюємо контракт у git
        mkdir -p contracts
        cp "$HOME/CYBRA/modules/module_19_contract_tui_menu/contracts/$cid"* \
           contracts/ 2>/dev/null || true

        git add -A 2>/dev/null
        if ! git diff --cached --quiet 2>/dev/null; then
            git commit -m "GUARDIAN: contract $cid [$(date -u +%FT%TZ)]" 2>&1 | tail -2
            git push 2>&1 | tail -2
        fi
    }

    # Snapshot
    echo "→ Guardian: creating snapshot..."
    gd_recovery_snapshot | tail -2

    echo "→ Guardian: OK for $cid"
}
