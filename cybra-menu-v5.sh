#!/data/data/com.termux/files/usr/bin/bash
# CYBRA MENU v5.0 — Unified Processes
CYBRA="$HOME/CYBRA"
REG_DIR="$HOME/.cybra"
REG="$REG_DIR/registry.json"
LOG="$REG_DIR/menu-v5.log"
mkdir -p "$REG_DIR"
[ -f "$REG" ] || echo '{"attached":{},"aliases":{}}' > "$REG"

R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'
C='\033[0;36m'; W='\033[1;37m'; DIM='\033[2m'; NC='\033[0m'

pause() { echo ""; read -p "  ↵ Enter..." _; }
log() { echo "[$(date '+%H:%M:%S')] $*" >> "$LOG"; }

detect_interp() {
    local f="$1"
    case "$f" in
        *.py) echo "python3" ;;
        *.js) echo "node" ;;
        *.sh) echo "bash" ;;
        *)
            local sb=$(head -1 "$f" 2>/dev/null)
            case "$sb" in
                *python*) echo "python3" ;;
                *node*)   echo "node" ;;
                *bash*|*sh*) echo "bash" ;;
                *) echo "bash" ;;
            esac ;;
    esac
}

detect_entry() {
    local d="$1"
    [ -d "$d" ] || return
    [ -f "$d/main.sh" ]   && { echo "bash|main.sh";   return; }
    [ -f "$d/main.py" ]   && { echo "python3|main.py"; return; }
    [ -f "$d/index.js" ]  && { echo "node|index.js";   return; }
    [ -f "$d/server.py" ] && { echo "python3|server.py"; return; }
    if [ -f "$d/package.json" ]; then
        local s=$(jq -r '.scripts.start // empty' "$d/package.json" 2>/dev/null)
        [ -n "$s" ] && { echo "npm|$s"; return; }
    fi
    local b=$(ls "$d/bin"/*.sh 2>/dev/null | head -1)
    [ -n "$b" ] && { echo "bash|bin/$(basename "$b")"; return; }
    local bp=$(ls "$d/bin"/*.py 2>/dev/null | head -1)
    [ -n "$bp" ] && { echo "python3|bin/$(basename "$bp")"; return; }
    echo ""
}

get_pm2_list() {
    pm2 jlist 2>/dev/null | jq -r '.[] | "\(.name)|\(.pm2_env.status)|\(.pm2_env.pm_exec_path // "-")"' 2>/dev/null
}

is_in_pm2() {
    local name="$1"
    get_pm2_list | grep -q "^$name|"
}

do_scan_processes() {
    clear; echo -e "${W}═══ СКАНУВАННЯ ПРОЦЕСІВ ═══${NC}\n"
    echo -e "${C}── PM2 ──${NC}"
    local pl=$(get_pm2_list)
    if [ -z "$pl" ]; then echo -e "  ${DIM}порожньо${NC}"; else
        echo "$pl" | awk -F'|' '{s="'"$Y"'"; if($2=="online")s="'"$G"'"; printf "  ● %-22s [%s%s%s]\n", $1, s, $2, "'"$NC"'"}' 2>/dev/null || \
        echo "$pl" | sed 's/|/ [/' | sed 's/$/]/'
    fi
    echo ""; echo -e "${C}── Файли-кандидати (не в PM2) ──${NC}"
    local cnt=0; cd "$CYBRA" || return
    for f in api/run.sh bin/cybra-monolith.py bin/cybra_taxi_events.py \
             bin/cybra_autogit.sh bin/cybra_neuro_controller.py \
             bin/cybra_evolution_controller.py bin/cybra_oracle_controller.py \
             bin/cybra_resurrection_controller.py bin/cybra_manifest.py \
             bin/cybra_reaper.py bin/cybra_dump.sh bin/cybra_sync.sh \
             core/autonomous-core.js cybra_level_tracker.sh \
             parliament_executor_v6.py parliament_menu_worker.sh \
             pancake-v3-ultimate-autofix.js cybra_codespace_runtime.py; do
        [ -f "$f" ] || continue
        local nm=$(basename "$f" | sed 's/\.[^.]*$//')
        is_in_pm2 "$nm" && continue
        cnt=$((cnt+1)); local it=$(detect_interp "$f")
        echo -e "  ${Y}$cnt)${NC} $f ${DIM}[$it]${NC}"
    done
    [ "$cnt" -eq 0 ] && echo -e "  ${DIM}немає нових${NC}"
    echo ""; echo -e "  ${DIM}Всього: $cnt${NC}"; pause
}

do_search() {
    clear; echo -e "${W}═══ ПОШУК ═══${NC}\n"
    read -p "  Запит: " q; [ -z "$q" ] && return
    echo ""; echo -e "${C}── PM2 ──${NC}"
    get_pm2_list | grep -i "$q" | awk -F'|' '{printf "  ● %-20s [%s]\n", $1, $2}' || echo -e "  ${DIM}нічого${NC}"
    echo ""; echo -e "${C}── Модулі ──${NC}"
    find "$CYBRA/modules" -maxdepth 2 -name manifest.json 2>/dev/null | while read -r m; do
        jq -r --arg q "$q" 'select((.name + " " + (.description // "")) | test($q; "i")) | "  ● \(.name) [\(.category // "?")] \(.description // "")"' "$m" 2>/dev/null
    done | head -15
    pause
}

do_start_any() {
    clear; echo -e "${W}═══ ЗАПУСК ФАЙЛУ ═══${NC}\n"
    read -p "  Шлях: " path; [ -z "$path" ] && return
    [ -f "$path" ] || [ -f "$CYBRA/$path" ] || { echo -e "${R}❌ нема${NC}"; pause; return; }
    [ -f "$path" ] || path="$CYBRA/$path"
    read -p "  Ім'я PM2 (Enter=basename): " name
    [ -z "$name" ] && name=$(basename "$path" | sed 's/\.[^.]*$//')
    local it=$(detect_interp "$path")
    echo -e "\n  ${C}▶ $it $path${NC}"
    pm2 start "$path" --name "$name" --interpreter "$it" --max-memory-restart 100M 2>&1 | tail -3
    sleep 2; pm2 list; log "start $name ($it $path)"; pause
}

do_autoboot() {
    clear; echo -e "${W}═══ ПІДНЯТИ ВСЕ ═══${NC}\n"
    echo "  1/4 — resurrect"
    pm2 resurrect 2>/dev/null | tail -2
    echo "  2/4 — базові"
    for n in cybra-monolith taxi-events level-tracker menu-worker parliament redis cybra-neuro cybra-evolution; do
        is_in_pm2 "$n" || { pm2 start "$n" 2>/dev/null; echo "  + $n"; }
    done
    echo "  3/4 — save"
    pm2 save --force 2>/dev/null && echo "  ✅"
    echo "  4/4 — backup"
    cp ~/.pm2/dump.pm2 ~/.pm2/dump.pm2.autoboot.$(date +%Y%m%d_%H%M%S) 2>/dev/null && echo "  ✅"
    echo ""; pm2 list; log "autoboot"; pause
}

do_save() {
    clear; echo -e "${G}SAVE dump ═══${NC}"
    pm2 save --force 2>/dev/null
    local ts=$(date +%Y%m%d_%H%M%S)
    cp ~/.pm2/dump.pm2 ~/.pm2/dump.pm2.manual.$ts 2>/dev/null
    echo "  ✅ dump.pm2.manual.$ts"
    jq -r '.[].name' ~/.pm2/dump.pm2 2>/dev/null | sed 's/^/    /'
    log "save $ts"; pause
}

do_backups() {
    clear; echo -e "${W}═══ БЕКАПИ ═══${NC}\n"
    local i=1; local arr=()
    for f in ~/.pm2/dump.pm2.*; do
        [ -f "$f" ] || continue
        local n=$(jq 'length' "$f" 2>/dev/null || echo "?")
        local sz=$(du -h "$f" | cut -f1)
        local dt=$(date -r "$f" '+%m-%d %H:%M')
        echo -e "  ${G}$i)${NC} $(basename "$f") ${DIM}($n proc, $sz, $dt)${NC}"
        arr+=("$f"); i=$((i+1))
    done
    echo ""; echo -e "  ${G}[r]${NC} Відновити  ${R}[d]${NC} Видалити  ${G}[Enter]${NC} назад"
    read -p "  Дія: " act
    if [ "$act" = "r" ]; then
        read -p "  #: " n; local f="${arr[$((n-1))]}"; [ -z "$f" ] && return
        cp "$f" ~/.pm2/dump.pm2; pm2 resurrect 2>/dev/null | tail -2; pm2 list
    elif [ "$act" = "d" ]; then
        read -p "  #: " n; local f="${arr[$((n-1))]}"
        [ -n "$f" ] && rm -f "$f" && echo "  ✅ видалено"
    fi
    pause
}

do_full_status() {
    clear; echo -e "${W}═══ ПОВНИЙ СТАТУС ═══${NC}\n"
    echo -e "${C}── PM2 ──${NC}"; pm2 list 2>/dev/null | tail -n +2 | head -20
    echo ""; echo -e "${C}── RAM ──${NC}"; free -h | head -2
    echo ""; echo -e "${C}── Dump ──${NC}"
    [ -f ~/.pm2/dump.pm2 ] && echo "  $(du -h ~/.pm2/dump.pm2 | cut -f1)  $(date -r ~/.pm2/dump.pm2 '+%m-%d %H:%M')" && jq -r '.[].name' ~/.pm2/dump.pm2 | sed 's/^/    /'
    echo ""; echo -e "${C}── Redis ──${NC}"; redis-cli dbsize 2>/dev/null | sed 's/^/  keys: /'
    pause
}

do_modules() {
    clear; echo -e "${W}═══ МОДУЛІ ═══${NC}\n"
    local arr=() i=1
    for d in "$CYBRA/modules"/*/; do
        [ -d "$d" ] || continue
        local n=$(basename "$d")
        if [ -f "$d/manifest.json" ]; then
            local stub=$(jq -r '.stub // false' "$d/manifest.json" 2>/dev/null)
            [ "$stub" = "true" ] && continue
        fi
        local entry=$(detect_entry "$d")
        local mark=""
        [ -z "$entry" ] && mark="${R}[no entry]${NC}" || mark="${G}[${entry%%|*}]${NC}"
        echo -e "  ${G}$i)${NC} $n $mark"
        arr+=("$n"); i=$((i+1))
    done
    [ ${#arr[@]} -eq 0 ] && { echo -e "${DIM}немає${NC}"; pause; return; }
    echo ""; echo -e "  ${G}[s]${NC} Запустити  ${G}[a]${NC} Прикріпити  ${G}[Enter]${NC} назад"
    read -p "  Дія: " act
    if [ "$act" = "s" ]; then
        read -p "  #: " n; local m="${arr[$((n-1))]}"; [ -n "$m" ] && do_run_module "$m"
    elif [ "$act" = "a" ]; then
        read -p "  #: " n; local m="${arr[$((n-1))]}"; [ -n "$m" ] && do_attach_module "$m"
    fi
    pause
}

do_run_module() {
    local name="$1"; local d="$CYBRA/modules/$name"
    local entry=$(detect_entry "$d")
    [ -z "$entry" ] && { echo -e "${R}❌ нема entrypoint${NC}"; return; }
    local it="${entry%%|*}"; local path="${entry##*|}"
    read -p "  Ім'я PM2 (Enter=$name): " pn
    [ -z "$pn" ] && pn="$name"
    if [ "$it" = "npm" ]; then
        (cd "$d" && pm2 start npm --name "$pn" -- start 2>&1 | tail -3)
    else
        pm2 start "$d/$path" --name "$pn" --interpreter "$it" --max-memory-restart 100M 2>&1 | tail -3
    fi
    sleep 2; pm2 list | grep -E "$pn" || echo -e "${Y}не піднявся${NC}"
    log "module run $name → $pn"
}

do_attach_module() {
    local name="$1"; local d="$CYBRA/modules/$name"
    local entry=$(detect_entry "$d")
    [ -z "$entry" ] && { echo -e "${R}❌ нема entrypoint${NC}"; return; }
    local it="${entry%%|*}"; local path="${entry##*|}"
    read -p "  Аліас (Enter=$name): " alias
    [ -z "$alias" ] && alias="$name"
    read -p "  Опис: " desc
    jq --arg a "$alias" --arg p "$d" --arg e "$path" --arg i "$it" --arg ds "$desc" --arg ts "$(date -u +%FT%TZ)" \
        '.attached[$a] = {"path":$p,"entry":$e,"interp":$i,"description":$ds,"attached_at":$ts}' \
        "$REG" > "$REG.tmp" && mv "$REG.tmp" "$REG"
    echo -e "${G}✅ $alias прикріплено${NC}"; log "attach $alias"
}

do_attached() {
    clear; echo -e "${W}═══ ПРИКРІПЛЕНІ ═══${NC}\n"
    local arr=() i=1
    for a in $(jq -r '.attached | keys[]' "$REG" 2>/dev/null); do
        local p=$(jq -r --arg a "$a" '.attached[$a].path' "$REG")
        local e=$(jq -r --arg a "$a" '.attached[$a].entry' "$REG")
        local it=$(jq -r --arg a "$a" '.attached[$a].interp' "$REG")
        local ds=$(jq -r --arg a "$a" '.attached[$a].description' "$REG")
        echo -e "  ${G}$i)${NC} ${W}$a${NC} ${DIM}[$it]${NC} $ds"
        echo -e "      ${DIM}$p/$e${NC}"
        arr+=("$a:$p:$e:$it"); i=$((i+1))
    done
    [ ${#arr[@]} -eq 0 ] && { echo -e "${DIM}немає. [М]одулі → [a]${NC}"; pause; return; }
    echo ""; echo -e "  ${G}[r]${NC} PM2 запуск  ${C}[t]${NC} Прямий тест  ${R}[d]${NC} Відкріпити  ${G}[Enter]${NC} назад"
    read -p "  Дія: " act
    case "$act" in
        r)
            read -p "  #: " n; local it="${arr[$((n-1))]}"; [ -z "$it" ] && return
            local a=$(echo "$it" | cut -d: -f1); local p=$(echo "$it" | cut -d: -f2)
            local e=$(echo "$it" | cut -d: -f3); local in=$(echo "$it" | cut -d: -f4)
            pm2 start "$p/$e" --name "$a" --interpreter "$in" --max-memory-restart 100M 2>&1 | tail -3
            ;;
        t)
            read -p "  #: " n; local it="${arr[$((n-1))]}"; [ -z "$it" ] && return
            local p=$(echo "$it" | cut -d: -f2); local e=$(echo "$it" | cut -d: -f3)
            local in=$(echo "$it" | cut -d: -f4)
            echo -e "\n  ${C}▶ Прямий запуск (5s):${NC}"
            timeout 5 bash -c "cd '$p' && $in '$e'" 2>&1 | head -20
            echo -e "\n  ${DIM}[exit: $?]${NC}"
            ;;
        d)
            read -p "  #: " n; local it="${arr[$((n-1))]}"
            local a=$(echo "$it" | cut -d: -f1)
            [ -n "$a" ] && jq --arg a "$a" 'del(.attached[$a])' "$REG" > "$REG.tmp" && mv "$REG.tmp" "$REG" && echo "  ✅ $a відкріплено"
            ;;
    esac
    pause
}

do_aliases() {
    clear; echo -e "${W}═══ АЛІАСИ ═══${NC}\n"
    local arr=() i=1
    for a in $(jq -r '.aliases | keys[]' "$REG" 2>/dev/null); do
        local c=$(jq -r --arg a "$a" '.aliases[$a].cmd' "$REG")
        echo -e "  ${G}$i)${NC} ${W}$a${NC} = ${DIM}$c${NC}"
        arr+=("$a"); i=$((i+1))
    done
    [ ${#arr[@]} -eq 0 ] && echo -e "${DIM}немає${NC}"
    echo ""; echo -e "  ${G}[a]${NC} Додати  ${R}[d]${NC} Видалити  ${G}[Enter]${NC} назад"
    read -p "  Дія: " act
    if [ "$act" = "a" ]; then
        read -p "  Ім'я: " a; read -p "  Команда: " c
        jq --arg a "$a" --arg c "$c" '.aliases[$a] = {"cmd":$c}' "$REG" > "$REG.tmp" && mv "$REG.tmp" "$REG"
        echo "  ✅ $a = $c"
    elif [ "$act" = "d" ]; then
        read -p "  #: " n; local a="${arr[$((n-1))]}"
        [ -n "$a" ] && jq --arg a "$a" 'del(.aliases[$a])' "$REG" > "$REG.tmp" && mv "$REG.tmp" "$REG" && echo "  ✅"
    fi
    pause
}

# main
while true; do
    clear
    echo -e "${C}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${C}║${W}     CYBRA MENU v5.0 — Unified Processes         ${C}║${NC}"
    echo -e "${C}║${DIM}  scan · search · start · save · backup · modules ${C}║${NC}"
    echo -e "${C}╚══════════════════════════════════════════════════╝${NC}"

    on=$(pm2 jlist 2>/dev/null | jq '[.[]|select(.pm2_env.status=="online")]|length' 2>/dev/null || echo 0)
    all=$(pm2 jlist 2>/dev/null | jq 'length' 2>/dev/null || echo 0)
    ram=$(free | awk '/Mem:/ {printf "%d", ($3/$2)*100}')
    att=$(jq -r '.attached | length' "$REG" 2>/dev/null || echo 0)
    dumps=$(ls ~/.pm2/dump.pm2.* 2>/dev/null | wc -l | tr -d ' ')
    echo -e "  ${DIM}┌─ статус ─────────────────────────────────────┐${NC}"
    echo -e "  ${DIM}│${NC} PM2 ${G}${on}${NC}/${Y}${all}${NC}  RAM ${Y}${ram}%${NC}  📎${C}${att}${NC}  💾${G}${dumps}${NC}"
    echo -e "  ${DIM}└──────────────────────────────────────────────┘${NC}"
    echo ""
    echo -e "  ${W}─── ПРОЦЕСИ ───${NC}"
    echo -e "  ${G}[1]${NC} Сканувати    ${G}[2]${NC} Пошук    ${G}[3]${NC} Запустити файл"
    echo ""
    echo -e "  ${W}─── ФІКСАЦІЯ / БЕКАПИ ───${NC}"
    echo -e "  ${G}[10]${NC} ${C}SAVE${NC}    ${G}[11]${NC} Бекапи    ${G}[12]${NC} ${Y}ПІДНЯТИ ВСЕ${NC}"
    echo ""
    echo -e "  ${W}─── МОДУЛІ ───${NC}"
    echo -e "  ${G}[20]${NC} Всі    ${G}[21]${NC} Прикріплені    ${G}[22]${NC} Аліаси"
    echo ""
    echo -e "  ${W}─── СТАТУС ───${NC}"
    echo -e "  ${G}[30]${NC} Full status    ${G}[31]${NC} Fix PM2"
    echo ""; echo -e "  ${R}[0]${NC} Вихід"
    echo ""
    read -p "  → " c
    case "$c" in
        1) do_scan_processes ;;
        2) do_search ;;
        3) do_start_any ;;
        10) do_save ;;
        11) do_backups ;;
        12) do_autoboot ;;
        20) do_modules ;;
        21) do_attached ;;
        22) do_aliases ;;
        30) do_full_status ;;
        31) pm2 update 2>&1 | tail -3; sleep 2; pause ;;
        0) echo -e "\n${G}  Бувай 👋${NC}\n"; exit 0 ;;
        *) sleep 1 ;;
    esac
done
