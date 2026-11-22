#!/data/data/com.termux/files/usr/bin/bash
# ==========================================
# CYBRA BAR MENU v4.0 — UNIFIED
# Sys + Neuro + Contracts + 108 Modules + Infra + PM2
# ==========================================
CYBRA_DIR="$HOME/CYBRA"; LOG="$CYBRA_DIR/.menu-v4.log"
R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'
M='\033[0;35m'; C='\033[0;36m'; W='\033[1;37m'; DIM='\033[2m'; NC='\033[0m'
log() { echo "[$(date '+%H:%M:%S')] $*" >> "$LOG"; }
pause() { echo ""; read -p "  ↵ Enter..." _; }

header() {
    clear
    echo -e "${M}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${M}║${W}       CYBRA BAR MENU v4.0  —  UNIFIED                   ${M}║${NC}"
    echo -e "${M}║${DIM}  sys · neuro · contracts · 108 modules · infra · pm2     ${M}║${NC}"
    echo -e "${M}╚════════════════════════════════════════════════════════════╝${NC}"
}

status_bar() {
    local on=$(pm2 jlist 2>/dev/null | jq '[.[]|select(.pm2_env.status=="online")]|length' 2>/dev/null || echo 0)
    local all=$(pm2 jlist 2>/dev/null | jq 'length' 2>/dev/null || echo 0)
    local ram=$(free | awk '/Mem:/ {printf "%d", ($3/$2)*100}')
    local lvl=$(cat "$CYBRA_DIR/.ctl.state" 2>/dev/null || echo "?")
    local real_mods=$(find "$CYBRA_DIR/modules" -maxdepth 2 -name manifest.json 2>/dev/null | xargs -r jq -r 'select(.stub != true) | .name' 2>/dev/null | wc -l | tr -d ' ')
    local stubs=$(find "$CYBRA_DIR/modules" -maxdepth 2 -name manifest.json 2>/dev/null | xargs -r jq -r 'select(.stub == true) | .name' 2>/dev/null | wc -l | tr -d ' ')
    local contracts=$(jq -r 'keys | map(select(startswith("_"))) | length' "$CYBRA_DIR/modules/autodopomoga/contracts.json" 2>/dev/null || echo "?")

    echo -e "  ${DIM}┌─ статус ─────────────────────────────────────────────────┐${NC}"
    echo -e "  ${DIM}│${NC} PM2 ${G}${on}${NC}/${Y}${all}${NC}  📦${G}${real_mods}${NC} real + ${DIM}${stubs} stub${NC}  📄${Y}${contracts}${NC} cont  RAM ${Y}${ram}%${NC}  L${C}${lvl}${NC} ${DIM}│${NC}"
    echo -e "  ${DIM}└──────────────────────────────────────────────────────────┘${NC}"
    echo ""
}

# ═══════ MODULES (108) ═══════
do_modules_all() {
    header; echo -e "${W}═══ ВСІ МОДУЛІ ═══${NC}\n"
    local i=0
    for m in "$CYBRA_DIR"/modules/*/manifest.json; do
        local d=$(dirname "$m")
        local name=$(jq -r '.name' "$m" 2>/dev/null)
        local cat=$(jq -r '.category // "?"' "$m" 2>/dev/null)
        local stub=$(jq -r '.stub // false' "$m" 2>/dev/null)
        local desc=$(jq -r '.description // ""' "$m" 2>/dev/null | head -c 40)
        i=$((i+1))
        if [ "$stub" = "true" ]; then
            echo -e "  ${DIM}○ $name [$cat] (stub)${NC}"
        else
            echo -e "  ${G}●${NC} ${W}$name${NC} ${C}[$cat]${NC} ${DIM}$desc${NC}"
        fi
    done
    echo ""
    echo -e "  Всього: $i"
    pause
}

do_modules_by_category() {
    header; echo -e "${W}═══ МОДУЛІ ПО КАТЕГОРІЯХ ═══${NC}\n"
    local cats=$(for m in "$CYBRA_DIR"/modules/*/manifest.json; do jq -r 'select(.stub != true) | .category // "?"' "$m" 2>/dev/null; done | sort -u)
    local i=1; local arr=()
    for c in $cats; do
        local count=$(for m in "$CYBRA_DIR"/modules/*/manifest.json; do jq -r --arg c "$c" 'select(.stub != true and .category == $c) | .name' "$m" 2>/dev/null; done | wc -l | tr -d ' ')
        echo -e "  ${G}$i)${NC} ${W}$c${NC} ${DIM}($count модулів)${NC}"
        arr+=("$c")
        i=$((i+1))
    done
    echo ""
    read -p "  → категорія (#): " n
    local idx=$((n-1))
    local cat="${arr[$idx]}"
    [ -z "$cat" ] && { pause; return; }
    echo ""
    echo -e "${C}── Модулі категорії $cat ──${NC}"
    for m in "$CYBRA_DIR"/modules/*/manifest.json; do
        jq -r --arg c "$cat" 'select(.stub != true and .category == $c) | "  ● \(.name) | \(.description // "")"' "$m" 2>/dev/null
    done
    pause
}

do_modules_search() {
    header; echo -e "${W}═══ ПОШУК МОДУЛЯ ═══${NC}\n"
    read -p "  Запит: " q
    [ -z "$q" ] && return
    echo ""
    find "$CYBRA_DIR/modules" -maxdepth 2 -name manifest.json 2>/dev/null | while read -r m; do
        jq -r --arg q "$q" 'select((.name + " " + (.description // "")) | test($q; "i")) | "  ● \(.name) | \(.category) | \(.description // "")"' "$m" 2>/dev/null
    done
    pause
}

do_modules_run() {
    header; echo -e "${W}═══ ЗАПУСК МОДУЛЯ ═══${NC}\n"
    read -p "  Назва модуля: " name
    [ -z "$name" ] && return
    local d="$CYBRA_DIR/modules/$name"
    [ -d "$d" ] || { echo -e "${R}❌ немає${NC}"; pause; return; }
    echo ""
    echo -e "${C}── Файли ──${NC}"
    ls "$d/bin" 2>/dev/null | sed 's/^/  bin: /'
    [ -f "$d/main.sh" ] && echo "  main: ✅"
    echo ""
    read -p "  Скрипт (bin/ім'я або main.sh): " scr
    if [ -f "$d/bin/$scr" ]; then
        bash "$d/bin/$scr" 2>&1 | head -40
    elif [ -f "$d/$scr" ]; then
        bash "$d/$scr" 2>&1 | head -40
    else
        echo -e "${R}❌ не знайдено${NC}"
    fi
    pause
}

do_redis_view() {
    header; echo -e "${W}═══ REDIS КЛЮЧІ ═══${NC}\n"
    echo -e "${C}── Всі cybra:* ключі ──${NC}"
    redis-cli --scan --pattern 'cybra:*' 2>/dev/null | head -30 | while read -r k; do
        local type=$(redis-cli type "$k" 2>/dev/null)
        local size="?"
        case "$type" in
            hash) size=$(redis-cli hlen "$k" 2>/dev/null) ;;
            list) size=$(redis-cli llen "$k" 2>/dev/null) ;;
            set)  size=$(redis-cli scard "$k" 2>/dev/null) ;;
            string) size=$(redis-cli strlen "$k" 2>/dev/null) ;;
        esac
        echo -e "  ${G}●${NC} $k ${DIM}($type: $size)${NC}"
    done
    echo ""
    redis-cli dbsize 2>/dev/null | sed 's/^/  Всього ключів: /'
    pause
}

# ═══════ CONTRACTS ═══════
do_contracts_all() {
    header; echo -e "${W}═══ ВСІ КОНТРАКТИ ═══${NC}\n"
    local f="$CYBRA_DIR/modules/autodopomoga/contracts.json"
    [ -f "$f" ] || { echo -e "${R}❌ нема${NC}"; pause; return; }
    for k in $(jq -r 'keys[] | select(startswith("_")|not)' "$f" 2>/dev/null); do
        local purpose=$(jq -r --arg k "$k" '.[$k].purpose // ""' "$f" 2>/dev/null)
        local weight=$(jq -r --arg k "$k" '.[$k].weight // "?"' "$f" 2>/dev/null)
        echo -e "  ${G}●${NC} ${W}$k${NC} ${DIM}(weight $weight)${NC}"
        echo -e "     ${DIM}$purpose${NC}"
    done
    pause
}

do_contracts_health() {
    header; echo -e "${W}═══ HEALTH CHECK ═══${NC}\n"
    local f="$CYBRA_DIR/modules/autodopomoga/contracts.json"
    export CYBRA="$CYBRA_DIR"
    for k in $(jq -r 'keys[] | select(startswith("_")|not)' "$f" 2>/dev/null); do
        local h=$(jq -r --arg k "$k" '.[$k].health // ""' "$f" 2>/dev/null)
        [ -z "$h" ] && { echo -e "  ${DIM}○ $k (без health)${NC}"; continue; }
        if bash -c "$h" >/dev/null 2>&1; then
            echo -e "  ${G}✅${NC} $k"
        else
            echo -e "  ${R}❌${NC} $k"
            echo -e "     ${DIM}health: $h${NC}"
        fi
    done
    pause
}

do_contracts_escalation() {
    header; echo -e "${W}═══ ESCALATION ═══${NC}\n"
    local f="$CYBRA_DIR/modules/autodopomoga/contracts.json"
    local i=1; local arr=()
    for k in $(jq -r 'keys[] | select(startswith("_")|not)' "$f" 2>/dev/null); do
        echo "  $i) $k"; arr+=("$k"); i=$((i+1))
    done
    read -p "  → " n
    local name="${arr[$((n-1))]}"
    [ -z "$name" ] && { pause; return; }
    echo ""
    echo -e "${C}── Escalation для $name ──${NC}"
    jq -r --arg k "$name" '.[$k].escalation[] | "  Attempt \(.attempt): \(.actions | join(" | "))"' "$f" 2>/dev/null
    echo ""
    read -p "  Виконати attempt 1? [y/N] " -n 1 -r; echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        export CYBRA="$CYBRA_DIR"
        jq -r --arg k "$name" '.[$k].escalation[0].actions[]' "$f" 2>/dev/null | while read -r cmd; do
            echo -e "${C}▶ $cmd${NC}"
            eval "$cmd" 2>&1 | head -10
        done
    fi
    log "escalation $name"; pause
}

# ═══════ INFRA ═══════
do_fortress() { header; echo -e "${G}Fortress...${NC}\n"; [ -x "$CYBRA_DIR/cybra-fortress-v2.sh" ] && bash "$CYBRA_DIR/cybra-fortress-v2.sh" 2>&1 | tail -20; pause; }
do_perms() { header; echo -e "${G}Auto-perms...${NC}\n"; [ -x "$CYBRA_DIR/cybra-perms.sh" ] && bash "$CYBRA_DIR/cybra-perms.sh" 2>&1 | tail -15; pause; }
do_ctl_status() { header; echo -e "${W}Controller:${NC} L$(cat "$CYBRA_DIR/.ctl.state" 2>/dev/null || echo '?')\n"; tail -15 "$CYBRA_DIR/.ctl.log" 2>/dev/null; pause; }
do_force_level() {
    header; echo "  1 SLEEP  2 CRIT  3 LOW  4 NORMAL  5 HIGH  6 TURBO  7 MAX"
    read -p "  Рівень [1-7]: " lvl
    [[ "$lvl" =~ ^[1-7]$ ]] && bash "$CYBRA_DIR/cybra-controller-v2.sh" --force-level "$lvl" 2>&1 | head -15
    pause
}

# ═══════ NEURO ═══════
do_neuro_status() {
    header; echo -e "${W}═══ NEURO ═══${NC}\n"
    for f in bin/cybra_neuro_controller.py bin/cybra_evolution_controller.py \
             bin/cybra_oracle_controller.py bin/cybra_resurrection_controller.py \
             dual-ai/orchestrator.js ; do
        [ -f "$CYBRA_DIR/$f" ] && echo -e "  ${G}●${NC} $f" || echo -e "  ${R}○${NC} $f"
    done
    echo ""
    echo -e "${C}── PM2 ──${NC}"
    pm2 jlist 2>/dev/null | jq -r '.[]|select(.name|test("neuro|evolution|oracle|resurrect|orchestrator"))|"  \(.name): \(.pm2_env.status)"'
    pause
}

# ═══════ PM2 ═══════
do_pm2() { header; pm2 list 2>/dev/null; pause; }
do_pm2_restart() { header; pm2 restart all 2>/dev/null; sleep 2; pm2 list; pause; }
do_save() {
    header; echo -e "${G}SAVE...${NC}"
    pm2 save --force 2>/dev/null
    local d="$HOME/.pm2/dump.pm2"
    [ -f "$d" ] && echo -e "  ✅ $(du -h "$d"|cut -f1), $(date -r "$d" '+%m-%d %H:%M:%S')"
    pause
}
do_resurrect() { header; pm2 resurrect 2>/dev/null; sleep 2; pm2 list; pause; }
do_backup() {
    header; local ts=$(date '+%Y%m%d_%H%M%S')
    cp "$HOME/.pm2/dump.pm2" "$HOME/.pm2/dump.pm2.bak.$ts" 2>/dev/null && echo -e "  ✅ dump.pm2.bak.$ts"
    pause
}
do_fix_pm2() { header; pm2 update 2>&1 | tail -3; pm2 list; pause; }

# ═══════ STATUS ═══════
do_full_status() {
    header; echo -e "${W}═══ FULL STATUS ═══${NC}\n"
    echo -e "${C}── PM2 ──${NC}"; pm2 list 2>/dev/null | tail -n +2 | head -25
    echo ""
    echo -e "${C}── RAM ──${NC}"; free -h | head -2
    echo ""
    echo -e "${C}── Модулі ──${NC}"
    echo "  Real: $(find "$CYBRA_DIR/modules" -maxdepth 2 -name manifest.json | xargs -r jq -r 'select(.stub != true) | .name' | wc -l | tr -d ' ')"
    echo "  Stubs: $(find "$CYBRA_DIR/modules" -maxdepth 2 -name manifest.json | xargs -r jq -r 'select(.stub == true) | .name' | wc -l | tr -d ' ')"
    echo ""
    echo -e "${C}── Redis ──${NC}"; redis-cli dbsize 2>/dev/null | sed 's/^/  keys: /'
    echo ""
    echo -e "${C}── Git ──${NC}"; cd "$CYBRA_DIR"; git log --oneline -3 2>/dev/null
    pause
}
do_retro() {
    header; echo -e "${W}═══ РЕТРОСПЕКТИВА ═══${NC}\n"
    cd "$CYBRA_DIR"
    echo -e "${C}── 30 днів ──${NC}"
    git log --oneline --since="30 days ago" 2>/dev/null | head -10
    echo ""
    echo -e "${C}── Модулі (real/stub) ──${NC}"
    echo "  Real: $(find modules -maxdepth 2 -name manifest.json | xargs -r jq -r 'select(.stub != true) | .name' | wc -l | tr -d ' ')"
    echo "  Stubs: $(find modules -maxdepth 2 -name manifest.json | xargs -r jq -r 'select(.stub == true) | .name' | wc -l | tr -d ' ')"
    echo ""
    echo -e "${C}── Redis ключів ──${NC}"; redis-cli dbsize 2>/dev/null | sed 's/^/  /'
    pause
}

# ═══════ MENU ═══════
menu() {
    echo -e "  ${M}╔══════ MODULES (108) ══════╗${NC}"
    echo -e "  ${G}[1]${NC} Всі модулі                ${G}[2]${NC} По категоріях"
    echo -e "  ${G}[3]${NC} Пошук                     ${G}[4]${NC} Запустити модуль"
    echo -e "  ${G}[5]${NC} Redis ключі"
    echo ""
    echo -e "  ${M}╔══════ CONTRACTS ══════╗${NC}"
    echo -e "  ${G}[10]${NC} Список                   ${G}[11]${NC} Health check ALL"
    echo -e "  ${G}[12]${NC} Escalation"
    echo ""
    echo -e "  ${M}╔══════ INFRA ══════╗${NC}"
    echo -e "  ${G}[20]${NC} Fortress                 ${G}[21]${NC} Perms"
    echo -e "  ${G}[22]${NC} Controller статус        ${G}[23]${NC} Примусовий рівень"
    echo ""
    echo -e "  ${M}╔══════ NEURO ══════╗${NC}"
    echo -e "  ${G}[30]${NC} NEURO статус"
    echo ""
    echo -e "  ${M}╔══════ PM2 / DUMP ══════╗${NC}"
    echo -e "  ${G}[40]${NC} List                     ${G}[41]${NC} Restart all"
    echo -e "  ${G}[42]${NC} ${C}SAVE${NC}                     ${G}[43]${NC} ${C}RESURRECT${NC}"
    echo -e "  ${G}[44]${NC} Backup                   ${G}[45]${NC} Fix PM2"
    echo ""
    echo -e "  ${M}╔══════ STATUS ══════╗${NC}"
    echo -e "  ${G}[50]${NC} Full status              ${G}[51]${NC} Ретроспектива"
    echo -e "  ${G}[52]${NC} Git commit + push"
    echo ""
    echo -e "  ${R}[0]${NC} Вихід"
}

do_git_push() {
    header; echo -e "${W}═══ GIT COMMIT + PUSH ═══${NC}\n"
    cd "$CYBRA_DIR"
    git status --short | head -20
    echo ""
    read -p "  Повідомлення коміту: " msg
    [ -z "$msg" ] && msg="update: $(date +%Y-%m-%d)"
    git add -A
    git commit -m "$msg" 2>&1 | tail -5
    read -p "  Push на origin? [y/N] " -n 1 -r; echo ""
    [[ $REPLY =~ ^[Yy]$ ]] && git push origin main 2>&1 | tail -5
    pause
}

while true; do
    header; status_bar; menu
    echo ""
    read -p "  → " choice
    case "$choice" in
        1) do_modules_all ;;
        2) do_modules_by_category ;;
        3) do_modules_search ;;
        4) do_modules_run ;;
        5) do_redis_view ;;
        10) do_contracts_all ;;
        11) do_contracts_health ;;
        12) do_contracts_escalation ;;
        20) do_fortress ;;
        21) do_perms ;;
        22) do_ctl_status ;;
        23) do_force_level ;;
        30) do_neuro_status ;;
        40) do_pm2 ;;
        41) do_pm2_restart ;;
        42) do_save ;;
        43) do_resurrect ;;
        44) do_backup ;;
        45) do_fix_pm2 ;;
        50) do_full_status ;;
        51) do_retro ;;
        52) do_git_push ;;
        0) echo -e "\n${G}  Бувай 👋${NC}\n"; exit 0 ;;
        *) sleep 1 ;;
    esac
done
