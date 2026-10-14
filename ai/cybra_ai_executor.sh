#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
# CYBRA AI EXECUTOR
# Аналізує систему → пропонує еволюцію → застосовує (safe only)
# ============================================================

set -u
export LC_ALL=C

ROOT="$HOME/CYBRA"
MODULES="$ROOT/modules"
BASELINE="$ROOT/baseline"
EVO_DIR="$ROOT/evolution"
AI_DIR="$ROOT/ai"
EVO_SUGGESTIONS="$AI_DIR/evolution/suggestions"
EVO_APPLIED="$AI_DIR/evolution/applied"
EVO_LOG="$AI_DIR/evolution/evolution.log"

mkdir -p "$EVO_SUGGESTIONS" "$EVO_APPLIED" "$AI_DIR/evolution"

# --- Кольори ---
if [ -t 1 ]; then
    R=$'\033[31m'; G=$'\033[32m'; Y=$'\033[33m'
    B=$'\033[1m'; C=$'\033[36m'; M=$'\033[35m'; Z=$'\033[0m'
else
    R=""; G=""; Y=""; B=""; C=""; M=""; Z=""
fi

ai_evo_log() {
    printf '%s | %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >> "$EVO_LOG"
}

# ============================================================
# SYSTEM SCAN
# ============================================================

scan_system() {
    local score=0

    printf '%s═══ SYSTEM SCAN ═══%s\n\n' "$B$C" "$Z"

    # --- Modules ---
    local mod_count=0
    for d in "$MODULES"/*/; do
        [ -d "$d" ] || continue
        m="$(basename "$d")"
        case "$m" in @*|.*|_disabled*|evolution|answer_engine|node_modules) continue ;; esac
        mod_count=$((mod_count+1))
    done
    printf '  Modules:           %s\n' "$mod_count"
    score=$((score + mod_count))

    # --- Contracts ---
    local contract_count=0
    local contracts_dir="$MODULES/module_19_contract_tui_menu/contracts"
    [ -d "$contracts_dir" ] && contract_count="$(find "$contracts_dir" -name '*.env' 2>/dev/null | wc -l | tr -d ' ')"
    printf '  Contracts:         %s\n' "$contract_count"

    # --- Links ---
    local link_count=0
    local links_dir="$MODULES/module_19_contract_tui_menu/links"
    [ -d "$links_dir" ] && link_count="$(find "$links_dir" -name '*.link' 2>/dev/null | wc -l | tr -d ' ')"
    printf '  Links:             %s\n' "$link_count"

    # --- Ledgers ---
    local ledgers=0
    for l in license_ledger license_ledger_b creation_license_ledger refund_ledger; do
        [ -f "$MODULES/module_19_contract_tui_menu/evidence/$l.txt" ] && ledgers=$((ledgers+1))
    done
    printf '  Ledgers:           %s\n' "$ledgers"

    # --- Tests ---
    local tests_found=0
    for d in "$MODULES"/*/; do
        [ -d "$d" ] || continue
        [ -f "$d/tests/run_tests.sh" ] && tests_found=$((tests_found+1))
    done
    printf '  Test runners:      %s\n' "$tests_found"

    # --- AI ---
    local ai_modules=0
    [ -f "$MODULES/module_19_contract_tui_menu/bin/cybra_local_ai.sh" ] && ai_modules=$((ai_modules+1))
    [ -f "$ROOT/CYBRA_AI_TASK_BAR.sh" ] && ai_modules=$((ai_modules+1))
    printf '  AI modules:        %s\n' "$ai_modules"

    # --- Freeze state ---
    local frozen=NO
    [ -f "$EVO_DIR/FROZEN" ] && frozen=YES
    printf '  Frozen:            %s\n' "$frozen"

    # --- Rates ---
    local rates=0
    [ -f "$MODULES/module_19_contract_tui_menu/state/rates.env" ] && rates=1
    printf '  Rates system:      %s\n' "$rates"

    printf '\n'
    printf '  System score: %s\n' "$score"
    printf '  Scan ID:      %s\n' "$(date -u +%Y%m%dT%H%M%SZ)"
    printf '\n'

    # --- Експорт у файл ---
    {
        printf 'MODULES=%s\n' "$mod_count"
        printf 'CONTRACTS=%s\n' "$contract_count"
        printf 'LINKS=%s\n' "$link_count"
        printf 'LEDGERS=%s\n' "$ledgers"
        printf 'TESTS=%s\n' "$tests_found"
        printf 'AI=%s\n' "$ai_modules"
        printf 'FROZEN=%s\n' "$frozen"
        printf 'SCORE=%s\n' "$score"
    } > "$AI_DIR/evolution/last_scan.env"

    return 0

        if [ "$applied_ok" -eq 1 ]; then
            printf '%s | applied at %s\n' "$name" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
                > "$EVO_APPLIED/${name}.applied"
            ai_evo_log "APPLIED: $name"
            applied=$((applied+1))
        else
            printf '%s | skipped (no handler) at %s\n' "$name" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
                > "$EVO_APPLIED/${name}.applied"
            skipped=$((skipped+1))
        fi
    done < <(find "$EVO_SUGGESTIONS" -maxdepth 1 -name '*.txt' -type f 2>/dev/null | sort)

    printf '\n'
    printf '  Total:   %s\n' "$total"
    printf '  Applied: %s\n' "$applied"
    printf '  Skipped: %s\n' "$skipped"
    printf '\n'

    return 0

        # Позначаємо як applied
        printf '%s | applied at %s\n' "$name" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
            > "$EVO_APPLIED/${name}.applied"
        ai_evo_log "APPLIED: $name"
        applied=$((applied+1))
    done

    printf '\n'
    printf '  Applied: %s\n' "$applied"
    printf '  Skipped: %s\n' "$skipped"
    printf '\n'

    return 0
