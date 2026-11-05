#!/data/data/com.termux/files/usr/bin/bash

set -u

DIR="$HOME/CYBRA/openid"
APP="cybra-openid"
ENV_FILE="$DIR/.env"

STATE_DIR="$DIR/state"
LOG_DIR="$DIR/logs"

STATE_FILE="$STATE_DIR/health-check.state"
LOG_FILE="$LOG_DIR/health-check.log"

mkdir -p "$STATE_DIR" "$LOG_DIR"

# --------------------------------------------------
# Load .env safely for shell-compatible KEY=VALUE
# --------------------------------------------------

if [ -f "$ENV_FILE" ]; then
    set -a
    # shellcheck disable=SC1090
    . "$ENV_FILE"
    set +a
fi

# --------------------------------------------------
# Configuration
# --------------------------------------------------

HEALTH_URL="${HEALTH_URL:-http://127.0.0.1:8787/health}"

CHECK_INTERVAL="${HEALTH_CHECK_INTERVAL:-30}"
FAIL_LIMIT="${HEALTH_FAIL_LIMIT:-3}"

MAX_RESTARTS="${HEALTH_MAX_RESTARTS:-5}"

# Restart accounting window
RESTART_WINDOW="${HEALTH_RESTART_WINDOW:-600}"

# Cooldown after restart budget exhaustion
COOLDOWN="${HEALTH_RESTART_COOLDOWN:-900}"

# curl timeout
CURL_TIMEOUT="${HEALTH_CURL_TIMEOUT:-5}"

# --------------------------------------------------
# Runtime state
# --------------------------------------------------

FAIL_COUNT=0
RESTART_COUNT=0
WINDOW_START=0
COOLDOWN_UNTIL=0

# --------------------------------------------------
# Helpers
# --------------------------------------------------

timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

log() {
    printf '%s %s\n' "$(timestamp)" "$*" | tee -a "$LOG_FILE"
}

is_uint() {
    case "$1" in
        ''|*[!0-9]*) return 1 ;;
        *) return 0 ;;
    esac
}

validate_config() {
    local name value

    for name in \
        CHECK_INTERVAL \
        FAIL_LIMIT \
        MAX_RESTARTS \
        RESTART_WINDOW \
        COOLDOWN \
        CURL_TIMEOUT
    do
        eval "value=\${$name}"

        if ! is_uint "$value"; then
            log "[ERROR] Invalid $name=$value"
            exit 1
        fi
    done

    if [ "$CHECK_INTERVAL" -lt 1 ]; then
        log "[ERROR] HEALTH_CHECK_INTERVAL must be >= 1"
        exit 1
    fi

    if [ "$FAIL_LIMIT" -lt 1 ]; then
        log "[ERROR] HEALTH_FAIL_LIMIT must be >= 1"
        exit 1
    fi

    if [ "$MAX_RESTARTS" -lt 1 ]; then
        log "[ERROR] HEALTH_MAX_RESTARTS must be >= 1"
        exit 1
    fi
}

load_state() {
    [ -f "$STATE_FILE" ] || return 0

    while IFS='=' read -r key value; do
        case "$key" in
            FAIL_COUNT)
                is_uint "$value" && FAIL_COUNT="$value"
                ;;
            RESTART_COUNT)
                is_uint "$value" && RESTART_COUNT="$value"
                ;;
            WINDOW_START)
                is_uint "$value" && WINDOW_START="$value"
                ;;
            COOLDOWN_UNTIL)
                is_uint "$value" && COOLDOWN_UNTIL="$value"
                ;;
        esac
    done < "$STATE_FILE"
}

save_state() {
    local tmp="${STATE_FILE}.tmp.$$"

    {
        echo "FAIL_COUNT=$FAIL_COUNT"
        echo "RESTART_COUNT=$RESTART_COUNT"
        echo "WINDOW_START=$WINDOW_START"
        echo "COOLDOWN_UNTIL=$COOLDOWN_UNTIL"
    } > "$tmp"

    mv "$tmp" "$STATE_FILE"
}

health_ok() {
    curl \
        --silent \
        --show-error \
        --fail \
        --max-time "$CURL_TIMEOUT" \
        "$HEALTH_URL" \
        >/dev/null 2>&1
}

reset_window_if_needed() {
    local now="$1"

    if [ "$WINDOW_START" -eq 0 ]; then
        WINDOW_START="$now"
        RESTART_COUNT=0
        return
    fi

    if [ $((now - WINDOW_START)) -ge "$RESTART_WINDOW" ]; then
        log "[INFO] Restart window reset"

        WINDOW_START="$now"
        RESTART_COUNT=0
    fi
}

restart_app() {
    log "[SELF-HEAL] Restarting $APP"

    if pm2 restart "$APP" --update-env >>"$LOG_FILE" 2>&1; then
        log "[SELF-HEAL] PM2 restart accepted"
        return 0
    fi

    log "[ERROR] PM2 restart failed"
    return 1
}

# --------------------------------------------------
# Startup
# --------------------------------------------------

validate_config
load_state

log "========================================"
log "CYBRA OPEN ID HEALTH-CHECK STARTED"
log "URL=$HEALTH_URL"
log "interval=${CHECK_INTERVAL}s"
log "fail_limit=$FAIL_LIMIT"
log "restart_limit=$MAX_RESTARTS"
log "restart_window=${RESTART_WINDOW}s"
log "cooldown=${COOLDOWN}s"
log "========================================"

# --------------------------------------------------
# Main loop
# --------------------------------------------------

while true; do

    NOW="$(date +%s)"

    # ----------------------------------------------
    # Cooldown handling
    # ----------------------------------------------

    if [ "$COOLDOWN_UNTIL" -gt 0 ]; then

        if [ "$NOW" -lt "$COOLDOWN_UNTIL" ]; then
            REMAINING=$((COOLDOWN_UNTIL - NOW))

            log "[COOLDOWN] ${REMAINING}s remaining"

            # Health is still monitored during cooldown,
            # but restart attempts are suppressed.
            if health_ok; then
                log "[OK] API recovered during cooldown"

                FAIL_COUNT=0
                RESTART_COUNT=0
                WINDOW_START="$NOW"
                COOLDOWN_UNTIL=0

                save_state
            fi

            sleep "$CHECK_INTERVAL"
            continue

        else

            log "[COOLDOWN] Finished. Restart budget restored."

            FAIL_COUNT=0
            RESTART_COUNT=0
            WINDOW_START="$NOW"
            COOLDOWN_UNTIL=0

            save_state
        fi
    fi

    # ----------------------------------------------
    # Health request
    # ----------------------------------------------

    if health_ok; then

        if [ "$FAIL_COUNT" -gt 0 ]; then
            log "[RECOVERED] API healthy after $FAIL_COUNT failed checks"
        else
            log "[OK] API healthy"
        fi

        FAIL_COUNT=0
        reset_window_if_needed "$NOW"

        save_state
        sleep "$CHECK_INTERVAL"
        continue
    fi

    # ----------------------------------------------
    # Failure
    # ----------------------------------------------

    FAIL_COUNT=$((FAIL_COUNT + 1))

    log "[FAIL] health-check $FAIL_COUNT/$FAIL_LIMIT"

    save_state

    # Don't restart yet
    if [ "$FAIL_COUNT" -lt "$FAIL_LIMIT" ]; then
        sleep "$CHECK_INTERVAL"
        continue
    fi

    # ----------------------------------------------
    # Restart budget
    # ----------------------------------------------

    reset_window_if_needed "$NOW"

    if [ "$RESTART_COUNT" -ge "$MAX_RESTARTS" ]; then

        COOLDOWN_UNTIL=$((NOW + COOLDOWN))

        log "[LIMIT] Restart budget exhausted: $RESTART_COUNT/$MAX_RESTARTS"
        log "[COOLDOWN] Self-heal paused for ${COOLDOWN}s"

        FAIL_COUNT=0

        save_state

        sleep "$CHECK_INTERVAL"
        continue
    fi

    # ----------------------------------------------
    # Restart
    # ----------------------------------------------

    RESTART_COUNT=$((RESTART_COUNT + 1))
    FAIL_COUNT=0

    log "[RESTART] attempt $RESTART_COUNT/$MAX_RESTARTS"

    save_state

    restart_app || true

    # Give application a little time before checking again.
    sleep "$CHECK_INTERVAL"

done
