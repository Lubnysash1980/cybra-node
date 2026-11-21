#!/data/data/com.termux/files/usr/bin/bash
# ==========================================
# CYBRA BAR MENU v3.0
# SYS + NEURO + Contracts + Modules + PM2
# ==========================================

CYBRA_DIR="$HOME/CYBRA"
LOG="$CYBRA_DIR/.menu-v3.log"

R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'
B='\033[0;34m'; M='\033[0;35m'; C='\033[0;36m'; W='\033[1;37m'
DIM='\033[2m'; NC='\033[0m'

log() { echo "[$(date '+%H:%M:%S')] $*" >> "$LOG"; }
pause() { echo ""; read -p "  ↵ Enter..." _; }

header() {
    clear
    echo -e "${M}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${M}║${W}      CYBRA BAR MENU v3.0  —  SYS + NEURO + FIDIC         ${M}║${NC}"
    echo -e "${M}║${DIM}   sys · neuro · contracts · modules · pm2 · dump         ${M}║${NC}"
    echo -e "${M}╚════════════════════════════════════════════════════════════╝${NC}"
}

status_bar() {
    local on=$(pm2 jlist 2>/dev/null | jq '[.[]|select(.pm2_env.status=="online")]|length' 2>/dev/null || echo 0)
    local all=$(pm2 jlist 2>/dev/null | jq 'length' 2>/dev/null || echo 0)
    local ram=$(free | awk '/Mem:/ {printf "%d", ($3/$2)*100}')
    local lvl=$(cat "$CYBRA_DIR/.ctl.state" 2>/dev/null || echo "?")
    local contracts=$(jq -r 'keys | length' "$CYBRA_DIR/modules/autodopomoga/contracts.json" 2>/dev/null || echo "?")
    local modules=$(ls -d "$CYBRA_DIR/modules"/*/ 2>/dev/null | wc -l | tr -d ' ')

    local sys="—"; pgrep -f "autowatch" >/dev/null 2>&1 && sys="${G}up${NC}" || sys="${R}down${NC}"
    local neuro="—"; pm2 jlist 2>/dev/null | jq -e '.[]|select(.name|test("neuro|evolution|oracle"))|select(.pm2_env.status=="online")' >/dev/null 2>&1 && neuro="${G}up${NC}" || neuro="${R}down${NC}"

    echo -e "  ${DIM}┌─ статус ─────────────────────────────────────────────────┐${NC}"
    echo -e "  ${DIM}│${NC} PM2 ${G}${on}${NC}/${Y}${all}${NC}  SYS ${sys}  NEURO ${neuro}  📦${Y}${modules}${NC} mod  📄${G}${contracts}${NC} cont  RAM ${Y}${ram}%${NC}  Lvl ${C}L${lvl}${NC} ${DIM}│${NC}"
    echo -e "  ${DIM}└──────────────────────────────────────────────────────────┘${NC}"
    echo ""
}

# ═══════════ SYS (СИСТЕМА) ═══════════
do_sys_status() {
    header; echo -e "${W}═══ SYS — СИСТЕМА КОНТРОЛЕРІВ ═══${NC}\n"
    echo -e "${C}── Контролери у файлах ──${NC}"
    ls -la "$CYBRA_DIR/controllers/" 2>/dev/null | tail -n +2
    echo ""
    echo -e "${C}── Процеси SYS ──${NC}"
    for p in cybra_autowatch cybra_bg_dump cybra-autogit; do
        local pid=$(pgrep -f "$p" 2>/dev/null | head -1)
        if [ -n "$pid" ]; then
            echo -e "  ${G}●${NC} $p (PID $pid)"
        else
            echo -e "  ${R}○${NC} $p ${DIM}(не запущено)${NC}"
        fi
    done
    echo ""
    echo -e "${C}── PID-файли (.cache/) ──${NC}"
    ls -la "$CYBRA_DIR/.cache/" 2>/dev/null | grep -E "\.pid|\.lock" || echo "  (немає)"
    pause
}

do_sys_autowatch() {
    header; echo -e "${W}═══ AUTOWATCH (супервізор) ═══${NC}\n"
    local ctl="$CYBRA_DIR/bin/cybra_autowatch_ctl.sh"
    [ -f "$ctl" ] || { echo -e "${R}❌ autowatch_ctl.sh відсутній${NC}"; pause; return; }
    echo -e "  ${G}[1]${NC} start   ${R}[2]${NC} stop   ${Y}[3]${NC} status   ${C}[4]${NC} logs"
    read -p "  → " c
    case "$c" in
        1) bash "$ctl" start ;;
        2) bash "$ctl" stop ;;
        3) bash "$ctl" status 2>&1 | head -20 ;;
        4) tail -40 "$CYBRA_DIR/logs/autowatch.log" 2>/dev/null || tail -40 "$CYBRA_DIR/.cache/autowatch.log" 2>/dev/null ;;
    esac
    log "sys autowatch $c"; pause
}

do_sys_bg_dump() {
    header; echo -e "${W}═══ BG_DUMP ═══${NC}\n"
    local ctl="$CYBRA_DIR/bin/cybra_bg_dump_ctl.sh"
    [ -f "$ctl" ] || { echo -e "${R}❌ bg_dump_ctl.sh відсутній${NC}"; pause; return; }
    echo -e "  ${G}[1]${NC} start   ${R}[2]${NC} stop   ${Y}[3]${NC} status   ${C}[4]${NC} dump зараз"
    read -p "  → " c
    case "$c" in
        1) bash "$ctl" start ;;
        2) bash "$ctl" stop ;;
        3) bash "$ctl" status 2>&1 | head -20 ;;
        4) bash "$CYBRA_DIR/bin/cybra_bg_dump.sh" 2>&1 | head -30 ;;
    esac
    log "sys bg_dump $c"; pause
}

do_sys_module_controller() {
    header; echo -e "${W}═══ MODULE CONTROLLER ═══${NC}\n"
    local f="$CYBRA_DIR/controllers/module-controller.sh"
    if [ ! -f "$f" ]; then echo -e "${R}❌ відсутній${NC}"; pause; return; fi
    echo -e "${DIM}Перші 30 рядків:${NC}"
    head -30 "$f"
    echo ""
    echo -e "${G}[r]${NC} запустити   ${G}[s]${NC} status   ${G}[Enter]${NC} назад"
    read -p "  → " c
    case "$c" in
        r) bash "$f" 2>&1 | head -40 ;;
        s) bash "$f" status 2>&1 | head -20 ;;
    esac
    pause
}

do_sys_node_controller() {
    header; echo -e "${W}═══ NODE CONTROLLER ═══${NC}\n"
    local f="$CYBRA_DIR/controllers/node-controller.sh"
    if [ ! -f "$f" ]; then echo -e "${R}❌ відсутній${NC}"; pause; return; fi
    echo -e "${DIM}Перші 30 рядків:${NC}"
    head -30 "$f"
    echo ""
    echo -e "${G}[r]${NC} запустити   ${G}[s]${NC} status   ${G}[Enter]${NC} назад"
    read -p "  → " c
    case "$c" in
        r) bash "$f" 2>&1 | head -40 ;;
        s) bash "$f" status 2>&1 | head -20 ;;
    esac
    pause
}

do_sys_binmix() {
    header; echo -e "${W}═══ BINMIX (змішувач) ═══${NC}\n"
    local f="$CYBRA_DIR/bin/cybra_binmix"
    if [ ! -f "$f" ]; then echo -e "${R}❌ відсутній${NC}"; pause; return; fi
    echo -e "${DIM}Перші 30 рядків:${NC}"
    head -30 "$f"
    echo ""
    echo -e "${G}[r]${NC} запустити   ${G}[Enter]${NC} назад"
    read -p "  → " c
    [ "$c" = "r" ] && bash "$f" 2>&1 | head -40
    pause
}

# ═══════════ NEURO ═══════════
do_neuro_status() {
    header; echo -e "${W}═══ NEURO — МОЗОК ═══${NC}\n"
    echo -e "${C}── Файли ──${NC}"
    for f in bin/cybra_neuro_controller.py bin/cybra_evolution_controller.py \
             bin/cybra_oracle_controller.py bin/cybra_resurrection_controller.py \
             dual-ai/orchestrator.js node_cybra/bin/cybra_ai_bar.sh ; do
        if [ -f "$CYBRA_DIR/$f" ]; then
            echo -e "  ${G}●${NC} $f ${DIM}($(wc -l < "$CYBRA_DIR/$f") рядків)${NC}"
        else
            echo -e "  ${R}○${NC} $f ${DIM}(відсутній)${NC}"
        fi
    done
    echo ""
    echo -e "${C}── В PM2 ──${NC}"
    pm2 jlist 2>/dev/null | jq -r '.[] | select(.name|test("neuro|evolution|oracle|resurrect|orchestrator|ai")) | "  \(.name): \(.pm2_env.status)"' 2>/dev/null || echo "  (немає)"
    pause
}

do_neuro_run() {
    header; echo -e "${W}═══ NEURO — ЗАПУСК ═══${NC}\n"
    echo -e "  ${G}[1]${NC} neuro_controller.py"
    echo -e "  ${G}[2]${NC} evolution_controller.py"
    echo -e "  ${G}[3]${NC} oracle_controller.py"
    echo -e "  ${G}[4]${NC} resurrection_controller.py"
    echo -e "  ${G}[5]${NC} orchestrator.js"
    echo -e "  ${G}[6]${NC} ai_bar.sh"
    read -p "  → " c
    case "$c" in
        1) python3 "$CYBRA_DIR/bin/cybra_neuro_controller.py" 2>&1 | head -40 ;;
        2) python3 "$CYBRA_DIR/bin/cybra_evolution_controller.py" 2>&1 | head -40 ;;
        3) python3 "$CYBRA_DIR/bin/cybra_oracle_controller.py" 2>&1 | head -40 ;;
        4) python3 "$CYBRA_DIR/bin/cybra_resurrection_controller.py" 2>&1 | head -40 ;;
        5) node "$CYBRA_DIR/dual-ai/orchestrator.js" 2>&1 | head -40 ;;
        6) bash "$CYBRA_DIR/node_cybra/bin/cybra_ai_bar.sh" 2>&1 | head -40 ;;
    esac
    log "neuro run $c"; pause
}

do_neuro_pm2() {
    header; echo -e "${W}═══ NEURO — ПІД PM2 ═══${NC}\n"
    echo -e "  ${G}[1]${NC} Підняти neuro-контролери в PM2"
    echo -e "  ${R}[2]${NC} Зупинити neuro в PM2"
    read -p "  → " c
    case "$c" in
        1)
            pm2 start "$CYBRA_DIR/bin/cybra_neuro_controller.py" --name cybra-neuro --interpreter python3 --max-memory-restart 80M 2>/dev/null
            pm2 start "$CYBRA_DIR/bin/cybra_evolution_controller.py" --name cybra-evolution --interpreter python3 --max-memory-restart 80M 2>/dev/null
            pm2 start "$CYBRA_DIR/bin/cybra_oracle_controller.py" --name cybra-oracle --interpreter python3 --max-memory-restart 65M 2>/dev/null
            pm2 start "$CYBRA_DIR/bin/cybra_resurrection_controller.py" --name cybra-resurrection --interpreter python3 --max-memory-restart 65M 2>/dev/null
            pm2 start "$CYBRA_DIR/dual-ai/orchestrator.js" --name cybra-orchestrator --max-memory-restart 80M 2>/dev/null
            pm2 save --force 2>/dev/null
            pm2 list
            ;;
        2)
            pm2 delete cybra-neuro cybra-evolution cybra-oracle cybra-resurrection cybra-orchestrator 2>/dev/null
            pm2 save --force 2>/dev/null
            ;;
    esac
    log "neuro pm2 $c"; pause
}

do_neuro_generate() {
    header; echo -e "${W}═══ NEURO — ЗГЕНЕРУВАТИ МОДУЛЬ ═══${NC}\n"
    echo -e "  ${DIM}Використовує neuro_controller для створення нового модуля${NC}"
    echo ""
    read -p "  Назва модуля (напр. fidic): " mname
    [ -z "$mname" ] && { pause; return; }
    read -p "  Тип (node/module/contract): " mtype
    [ -z "$mtype" ] && mtype="module"
    echo ""
    echo -e "${Y}Виклик neuro_controller з параметрами...${NC}"
    if [ -f "$CYBRA_DIR/bin/cybra_neuro_controller.py" ]; then
        python3 "$CYBRA_DIR/bin/cybra_neuro_controller.py" --generate "$mname" --type "$mtype" 2>&1 | head -40
    else
        echo -e "${R}❌ neuro_controller.py відсутній${NC}"
    fi
    log "neuro generate $mname $mtype"; pause
}

# ═══════════ CONTRACTS (наявні 4) ═══════════
do_contracts() {
    header; echo -e "${W}═══ КОНТРАКТИ (самолікування) ═══${NC}\n"
    local f="$CYBRA_DIR/modules/autodopomoga/contracts.json"
    if [ ! -f "$f" ]; then echo -e "${R}❌ contracts.json${NC}"; pause; return; fi
    echo -e "${C}── Контракти ──${NC}"
    jq -r 'to_entries[] | "  ● \(.key) | weight=\(.value.weight // "?") | cooldown=\(.value.cooldown_sec // "?")s\n     \(.value.purpose // "")"' "$f" 2>/dev/null
    echo ""
    echo -e "${C}── Health check всіх ──${NC}"
    for k in $(jq -r 'keys[]' "$f" 2>/dev/null); do
        local health=$(jq -r --arg k "$k" '.[$k].health // ""' "$f" 2>/dev/null)
        if [ -n "$health" ]; then
            export CYBRA="$CYBRA_DIR"
            if bash -c "$health" >/dev/null 2>&1; then
                echo -e "  ${G}✅${NC} $k"
            else
                echo -e "  ${R}❌${NC} $k"
            fi
        fi
    done
    pause
}

do_contracts_escalation() {
    header; echo -e "${W}═══ ESCALATION ═══${NC}\n"
    local f="$CYBRA_DIR/modules/autodopomoga/contracts.json"
    echo -e "${C}Виберіть контракт:${NC}"
    local arr=($(jq -r 'keys[]' "$f" 2>/dev/null))
    local i=1
    for k in "${arr[@]}"; do
        echo "  $i) $k"
        i=$((i+1))
    done
    read -p "  → " n
    local idx=$((n-1))
    local name="${arr[$idx]}"
    [ -z "$name" ] && { pause; return; }
    echo ""
    echo -e "${Y}Escalation для $name:${NC}"
    jq -r --arg k "$name" '.[$k].escalation[] | "  Attempt \(.attempt): \(.actions | join(", "))"' "$f" 2>/dev/null
    echo ""
    read -p "  Виконати attempt 1? [y/N] " -n 1 -r; echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        jq -r --arg k "$name" '.[$k].escalation[0].actions[]' "$f" 2>/dev/null | while read -r cmd; do
            echo -e "${C}▶ $cmd${NC}"
            eval "$cmd" 2>&1 | head -10
        done
    fi
    log "escalation $name"; pause
}

do_contracts_sync() {
    header; echo -e "${G}Contracts sync...${NC}\n"
    [ -f "$CYBRA_DIR/modules/autodopomoga/bin/contracts_sync.sh" ] && \
        bash "$CYBRA_DIR/modules/autodopomoga/bin/contracts_sync.sh" 2>&1 | head -30
    log "contracts_sync"; pause
}

# ═══════════ MODULES ═══════════
do_modules() {
    header; echo -e "${W}═══ МОДУЛІ ═══${NC}\n"
    for m in "$CYBRA_DIR"/modules/*/; do
        local name=$(basename "$m")
        local manifest="$m/manifest.json"
        if [ -f "$manifest" ]; then
            local ver=$(jq -r '.version // "?"' "$manifest" 2>/dev/null)
            local desc=$(jq -r '.description // ""' "$manifest" 2>/dev/null | head -c 60)
            local st=$(ls "$m/state" 2>/dev/null | wc -l | tr -d ' ')
            echo -e "  ${G}●${NC} ${W}$name${NC} ${DIM}v$ver  state:$st${NC}"
            [ -n "$desc" ] && echo -e "     ${DIM}$desc${NC}"
        else
            echo -e "  ${Y}○${NC} $name ${DIM}(без manifest)${NC}"
        fi
    done
    pause
}

do_module_run() {
    header; echo -e "${W}═══ ЗАПУСК МОДУЛЯ ═══${NC}\n"
    local i=1
    local arr=($(ls -d "$CYBRA_DIR/modules"/*/ 2>/dev/null | xargs -n1 basename))
    for m in "${arr[@]}"; do
        echo "  $i) $m"
        i=$((i+1))
    done
    read -p "  → " n
    local idx=$((n-1))
    local mname="${arr[$idx]}"
    [ -z "$mname" ] && { pause; return; }
    local bin="$CYBRA_DIR/modules/$mname/bin"
    echo ""
    echo -e "${C}── bin/ в $mname ──${NC}"
    ls "$bin" 2>/dev/null | sed 's/^/  /'
    read -p "  Скрипт (ім'я): " scr
    [ -f "$bin/$scr" ] && bash "$bin/$scr" 2>&1 | head -40 || echo -e "${R}❌ немає${NC}"
    log "module run $mname/$scr"; pause
}

# ═══════════ PM2 / NOHUP / DUMP ═══════════
do_pm2_list() { header; pm2 list 2>/dev/null; pause; }
do_pm2_restart() { header; echo -e "${Y}restart all${NC}"; pm2 restart all 2>/dev/null; sleep 2; pm2 list; log "restart all"; pause; }
do_save() {
    header; echo -e "${G}SAVE...${NC}"
    pm2 save --force 2>/dev/null
    local d="$HOME/.pm2/dump.pm2"
    [ -f "$d" ] && echo -e "  ✅ $(du -h "$d"|cut -f1), $(date -r "$d" '+%m-%d %H:%M:%S')"
    log "save"; pause
}
do_resurrect() { header; echo -e "${C}RESURRECT...${NC}"; pm2 resurrect 2>/dev/null; sleep 2; pm2 list; log "resurrect"; pause; }
do_backup() {
    header; echo -e "${G}Backup dump...${NC}"
    local ts=$(date '+%Y%m%d_%H%M%S')
    cp "$HOME/.pm2/dump.pm2" "$HOME/.pm2/dump.pm2.backup.$ts" 2>/dev/null && \
      echo -e "  ✅ dump.pm2.backup.$ts"
    log "backup $ts"; pause
}
do_fix_pm2() {
    header; echo -e "${Y}Fix PM2 (update daemon)...${NC}"
    pm2 update 2>&1 | tail -5
    pm2 list
    pause
}

# ═══════════ STATUS ═══════════
do_full_status() {
    header; echo -e "${W}═══ FULL STATUS ═══${NC}\n"
    echo -e "${C}── PM2 ──${NC}"; pm2 list 2>/dev/null | tail -n +2; echo ""
    echo -e "${C}── RAM ──${NC}"; free -h | head -2; echo ""
    echo -e "${C}── SYS ──${NC}"
    pgrep -f "autowatch" >/dev/null && echo "  ✅ autowatch" || echo "  ❌ autowatch"
    pgrep -f "bg_dump" >/dev/null && echo "  ✅ bg_dump" || echo "  ❌ bg_dump"
    echo ""
    echo -e "${C}── NEURO ──${NC}"
    pm2 jlist 2>/dev/null | jq -r '.[]|select(.name|test("neuro|evolution|oracle"))|"  \(.name): \(.pm2_env.status)"' 2>/dev/null || echo "  (не в PM2)"
    echo ""
    echo -e "${C}── Контракти ──${NC}"
    jq -r 'to_entries[]|"  \(.key) (weight \(.value.weight))"' "$CYBRA_DIR/modules/autodopomoga/contracts.json" 2>/dev/null
    echo ""
    echo -e "${C}── Controller ──${NC}"; echo "  L$(cat "$CYBRA_DIR/.ctl.state" 2>/dev/null || echo '?')"
    pause
}

# ═══════════ MENU ═══════════
menu() {
    echo -e "  ${M}╔══════ SYS (система) ══════╗${NC}"
    echo -e "  ${G}[1]${NC}  SYS статус (всі контролери)  ${G}[2]${NC}  Autowatch ctl"
    echo -e "  ${G}[3]${NC}  BG_dump ctl                  ${G}[4]${NC}  Module controller"
    echo -e "  ${G}[5]${NC}  Node controller              ${G}[6]${NC}  Binmix"
    echo ""
    echo -e "  ${M}╔══════ NEURO (мозок) ══════╗${NC}"
    echo -e "  ${G}[10]${NC} NEURO статус                 ${G}[11]${NC} NEURO запуск (вибір)"
    echo -e "  ${G}[12]${NC} NEURO під PM2                ${G}[13]${NC} ${Y}Згенерувати модуль${NC}"
    echo ""
    echo -e "  ${M}╔══════ CONTRACTS (4) ══════╗${NC}"
    echo -e "  ${G}[20]${NC} Список + health check        ${G}[21]${NC} Escalation виконати"
    echo -e "  ${G}[22]${NC} Contracts sync               ${G}[23]${NC} Git-історія"
    echo ""
    echo -e "  ${M}╔══════ MODULES ══════╗${NC}"
    echo -e "  ${G}[30]${NC} Огляд модулів               ${G}[31]${NC} Запустити скрипт модуля"
    echo -e "  ${G}[32]${NC} Parliament                   ${G}[33]${NC} Stake→dump"
    echo ""
    echo -e "  ${M}╔══════ PM2 / DUMP ══════╗${NC}"
    echo -e "  ${G}[40]${NC} PM2 list                     ${G}[41]${NC} Restart all"
    echo -e "  ${G}[42]${NC} ${C}SAVE${NC}                         ${G}[43]${NC} ${C}RESURRECT${NC}"
    echo -e "  ${G}[44]${NC} Backup dump                  ${G}[45]${NC} Fix PM2 (update)"
    echo ""
    echo -e "  ${M}╔══════ STATUS ══════╗${NC}"
    echo -e "  ${G}[50]${NC} FULL STATUS                  ${G}[51]${NC} Ретроспектива"
    echo -e "  ${G}[52]${NC} Логи                         ${G}[53]${NC} ${Y}Відновити все${NC}"
    echo ""
    echo -e "  ${R}[0]${NC}  Вихід"
}

do_retro() {
    header; echo -e "${W}═══ РЕТРОСПЕКТИВА ═══${NC}\n"
    cd "$CYBRA_DIR"
    echo -e "${C}── Останні 30 днів git ──${NC}"
    git log --oneline --since="30 days ago" 2>/dev/null | head -15
    echo ""
    echo -e "${C}── Модулів: $(ls -d modules/*/ 2>/dev/null | wc -l | tr -d ' ')${NC}"
    echo -e "${C}── Контрактів: $(jq 'keys|length' modules/autodopomoga/contracts.json 2>/dev/null)${NC}"
    echo -e "${C}── PM2 online: $(pm2 jlist 2>/dev/null | jq '[.[]|select(.pm2_env.status=="online")]|length')${NC}"
    echo -e "${C}── NEURO у файлах: $(ls bin/cybra_*controller.py 2>/dev/null | wc -l | tr -d ' ')${NC}"
    pause
}

do_logs() {
    header; echo -e "${W}═══ ЛОГИ ═══${NC}\n"
    echo "  [1] PM2  [2] .menu-v3  [3] autowatch  [4] bg_dump"
    read -p "  → " c
    case "$c" in
        1) timeout 5 pm2 logs --lines 30 2>/dev/null ;;
        2) tail -40 "$LOG" ;;
        3) tail -40 "$CYBRA_DIR/logs/autowatch.log" 2>/dev/null; pause ;;
        4) tail -40 "$CYBRA_DIR/logs/bg_dump.log" 2>/dev/null; pause ;;
    esac
}

do_full_restore() {
    header; echo -e "${Y}Повне відновлення...${NC}\n"
    [ -x "$CYBRA_DIR/cybra-perms.sh" ] && bash "$CYBRA_DIR/cybra-perms.sh" >/dev/null 2>&1 && echo "  ✅ perms"
    pm2 resurrect 2>/dev/null && echo "  ✅ resurrect"; sleep 2
    pm2 restart all 2>/dev/null && echo "  ✅ restart"; sleep 2
    pm2 save --force 2>/dev/null && echo "  ✅ save"
    echo ""; pm2 list
    log "full restore"; pause
}

do_parliament() {
    header; echo -e "${W}═══ PARLIAMENT ═══${NC}\n"
    local pdir="$CYBRA_DIR/modules/parliament/state/proposals"
    [ -d "$pdir" ] && echo -e "  Пропозицій: ${G}$(ls "$pdir" | wc -l | tr -d ' ')${NC}" || echo "  (немає)"
    echo ""
    echo -e "${C}── bin/ ──${NC}"; ls "$CYBRA_DIR/modules/parliament/bin" 2>/dev/null | sed 's/^/  /'
    read -p "  Скрипт (Enter=назад): " s
    [ -n "$s" ] && bash "$CYBRA_DIR/modules/parliament/bin/$s" 2>&1 | head -30
    pause
}

do_stake() {
    header; echo -e "${W}═══ STAKE→DUMP ═══${NC}\n"
    local d="$CYBRA_DIR/modules/stakeawtodump"
    [ -f "$d/state/status.json" ] && jq -c '.' "$d/state/status.json" 2>/dev/null | head -3
    echo ""
    echo -e "${C}── bin/ ──${NC}"; ls "$d/bin" 2>/dev/null | sed 's/^/  /'
    read -p "  Скрипт (Enter=назад): " s
    [ -n "$s" ] && bash "$d/bin/$s" 2>&1 | head -40
    pause
}

while true; do
    header; status_bar; menu
    echo ""
    read -p "  → " choice
    case "$choice" in
        1) do_sys_status ;;
        2) do_sys_autowatch ;;
        3) do_sys_bg_dump ;;
        4) do_sys_module_controller ;;
        5) do_sys_node_controller ;;
        6) do_sys_binmix ;;
        10) do_neuro_status ;;
        11) do_neuro_run ;;
        12) do_neuro_pm2 ;;
        13) do_neuro_generate ;;
        20) do_contracts ;;
        21) do_contracts_escalation ;;
        22) do_contracts_sync ;;
        23) cd "$CYBRA_DIR" && git log --oneline -- modules/autodopomoga/ 2>/dev/null | head -20 && pause ;;
        30) do_modules ;;
        31) do_module_run ;;
        32) do_parliament ;;
        33) do_stake ;;
        40) do_pm2_list ;;
        41) do_pm2_restart ;;
        42) do_save ;;
        43) do_resurrect ;;
        44) do_backup ;;
        45) do_fix_pm2 ;;
        50) do_full_status ;;
        51) do_retro ;;
        52) do_logs ;;
        53) do_full_restore ;;
        0) echo -e "\n${G}  Бувай 👋${NC}\n"; exit 0 ;;
        *) echo -e "${R}  ?${NC}"; sleep 1 ;;
    esac
done
