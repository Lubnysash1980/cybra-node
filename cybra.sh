#!/data/data/com.termux/files/usr/bin/bash
CYBRA="$HOME/CYBRA"
REG="$HOME/.cybra/registry.json"
mkdir -p "$HOME/.cybra"
[ -f "$REG" ] || echo '{"attached":{}}' > "$REG"

R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; C='\033[0;36m'
W='\033[1;37m'; D='\033[2m'; N='\033[0m'
p() { echo ""; read -p "  ↵ Enter..." _; }

di() { case "$1" in *.py) echo python3;; *.js) echo node;; *.sh) echo bash;; *) local s=$(head -1 "$1" 2>/dev/null); case "$s" in *python*) echo python3;; *node*) echo node;; *) echo bash;; esac;; esac; }

de() {
    local d="$1"
    [ -f "$d/main.sh" ]&&{ echo "bash|main.sh"; return; }
    [ -f "$d/main.py" ]&&{ echo "python3|main.py"; return; }
    [ -f "$d/index.js" ]&&{ echo "node|index.js"; return; }
    [ -f "$d/server.py" ]&&{ echo "python3|server.py"; return; }
    local b=$(ls "$d/bin"/*.sh 2>/dev/null|head -1)
    [ -n "$b" ]&&{ echo "bash|bin/$(basename "$b")"; return; }
    echo ""
}

status() {
    local on=$(pm2 jlist 2>/dev/null|jq '[.[]|select(.pm2_env.status=="online")]|length' 2>/dev/null||echo 0)
    local all=$(pm2 jlist 2>/dev/null|jq 'length' 2>/dev/null||echo 0)
    local ram=$(free|awk '/Mem:/ {printf "%d",($3/$2)*100}')
    local in=$(ls "$CYBRA/ai-tasks/inbox"/*.json 2>/dev/null|wc -l|tr -d ' ')
    local ap=$(ls "$CYBRA/ai-tasks/approved"/*.json 2>/dev/null|wc -l|tr -d ' ')
    local bx=$(bash "$CYBRA/binary-box/bin/box.sh" usage 2>/dev/null||echo "?")
    local at=$(jq -r '.attached|length' "$REG" 2>/dev/null||echo 0)
    echo -e "  ${D}┌─ STATUS ─────────────────────────────────────┐${N}"
    echo -e "  ${D}│${N} PM2 ${G}$on$N/${Y}$all$N  RAM ${Y}$ram%$N  📥${Y}$in$N  ✅${G}$ap$N  📎${C}$at$N  📦${C}$bx$N ${D}│${N}"
    echo -e "  ${D}└──────────────────────────────────────────────┘${N}"
}

# ═══════════════ 1-3: ПРОЦЕСИ ═══════════════
do1() { clear; echo -e "${W}═══ 1. СКАНУВАННЯ ═══${N}\n"; echo -e "${C}── PM2 ──${N}"; pm2 list 2>/dev/null|tail -n +2|sed 's/^/  /'
    echo ""; echo -e "${C}── Файли (не в PM2) ──${N}"; local i=1
    for f in api/run.sh bin/cybra-monolith.py bin/cybra_taxi_events.py bin/cybra_autogit.sh bin/cybra_neuro_controller.py bin/cybra_evolution_controller.py core/autonomous-core.js cybra_level_tracker.sh parliament_executor_v6.py parliament_menu_worker.sh; do
        [ -f "$CYBRA/$f" ]||continue
        local n=$(basename "$f"|sed 's/\.[^.]*$//')
        pm2 jlist 2>/dev/null|grep -q "\"name\":\"$n\""&&continue
        echo -e "  ${Y}$i)${N} $f ${D}[$(di "$CYBRA/$f")]${N}"; i=$((i+1)); done
    [ "$i" -eq 1 ]&&echo -e "  ${D}нема${N}"; p; }

do2() { clear; echo -e "${W}═══ 2. ПОШУК ═══${N}\n"; read -p "  запит: " q; [ -z "$q" ]&&return
    echo -e "${C}── PM2 ──${N}"; pm2 list 2>/dev/null|grep -i "$q"|sed 's/^/  /'
    echo -e "${C}── Модулі ──${N}"; find "$CYBRA/modules" -maxdepth 2 -name manifest.json 2>/dev/null|while read m; do jq -r --arg q "$q" 'select((.name+" "+(.description//""))|test($q;"i"))|"  ● \(.name)"' "$m" 2>/dev/null; done|head -10; p; }

do3() { clear; echo -e "${W}═══ 3. ЗАПУСК ФАЙЛУ ═══${N}\n"; read -p "  шлях: " f; [ -z "$f" ]&&return
    [ -f "$f" ]||f="$CYBRA/$f"; [ -f "$f" ]||{ echo -e "${R}❌${N}"; p; return; }
    read -p "  ім'я: " n; [ -z "$n" ]&&n=$(basename "$f"|sed 's/\.[^.]*$//')
    pm2 start "$f" --name "$n" --interpreter "$(di "$f")" --max-memory-restart 100M 2>&1|tail -2; sleep 2; pm2 list|grep "$n"; p; }

# ═══════════════ 4-9: PM2 КЕРУВАННЯ ═══════════════
do4() { clear; echo -e "${W}═══ 4. ЗУПИНИТИ PM2 ═══${N}\n"; pm2 list 2>/dev/null|grep online|sed 's/^/  /'; read -p "  ім'я: " n; [ -n "$n" ]&&pm2 stop "$n"&&echo "✅"; p; }
do5() { clear; echo -e "${W}═══ 5. RESTART PM2 ALL ═══${N}"; pm2 restart all 2>&1|tail -3; sleep 2; pm2 list; p; }
do6() { clear; echo -e "${W}═══ 6. DELETE PM2 ═══${N}\n"; pm2 list 2>/dev/null|sed 's/^/  /'; read -p "  ім'я: " n; [ -n "$n" ]&&pm2 delete "$n"&&echo "✅"; p; }
do7() { clear; echo -e "${W}═══ 7. PM2 LIST ═══${N}\n"; pm2 list 2>/dev/null; p; }
do8() { clear; echo -e "${W}═══ 8. PM2 LOGS ═══${N}\n"; read -p "  ім'я (Enter=all): " n; if [ -z "$n" ]; then timeout 10 pm2 logs --lines 30 2>/dev/null; else timeout 10 pm2 logs "$n" --lines 30 2>/dev/null; fi; p; }
do9() { clear; echo -e "${W}═══ 9. FIX PM2 ═══${N}"; pm2 update 2>&1|tail -3; sleep 2; pm2 list; p; }

# ═══════════════ 10-18: ФІКСАЦІЯ / ДАМПИ ═══════════════
do10() { clear; echo -e "${G}═══ 10. SAVE dump ═══${N}"; pm2 save --force 2>/dev/null; local ts=$(date +%Y%m%d_%H%M%S); cp ~/.pm2/dump.pm2 ~/.pm2/dump.pm2.manual.$ts 2>/dev/null; echo "  ✅ dump.pm2.manual.$ts"; jq -r '.[].name' ~/.pm2/dump.pm2 2>/dev/null|sed 's/^/    /'; p; }
do11() { clear; echo -e "${W}═══ 11. БЕКАП dump ═══${N}"; local ts=$(date +%Y%m%d_%H%M%S); cp ~/.pm2/dump.pm2 ~/.pm2/dump.pm2.bak.$ts 2>/dev/null&&echo "  ✅ dump.pm2.bak.$ts"; p; }
do12() { clear; echo -e "${W}═══ 12. RESTORE з бекапу ═══${N}\n"; local i=1 a=(); for f in ~/.pm2/dump.pm2.*; do [ -f "$f" ]||continue; local n=$(jq 'length' "$f" 2>/dev/null||echo "?"); local d=$(date -r "$f" '+%m-%d %H:%M'); echo -e "  ${G}$i)${N} $(basename "$f") ${D}($n proc, $d)${N}"; a+=("$f"); i=$((i+1)); done; read -p "  #: " n; [ -z "${a[$((n-1))]}" ]&&{ p; return; }; cp "${a[$((n-1))]}" ~/.pm2/dump.pm2; pm2 resurrect 2>/dev/null|tail -1; pm2 list; p; }
do13() { clear; echo -e "${W}═══ 13. ПІДНЯТИ ВСЕ ═══${N}\n"; echo "  1/3 resurrect"; pm2 resurrect 2>/dev/null|tail -1; echo "  2/3 save"; pm2 save --force 2>/dev/null&&echo "  ✅"; echo "  3/3 backup"; cp ~/.pm2/dump.pm2 ~/.pm2/dump.pm2.autoboot.$(date +%Y%m%d_%H%M%S) 2>/dev/null; pm2 list; p; }
do14() { clear; echo -e "${W}═══ 14. СПИСОК БЕКАПІВ ═══${N}\n"; for f in ~/.pm2/dump.pm2.*; do [ -f "$f" ]||continue; echo -e "  $(basename "$f") ${D}($(jq 'length' "$f" 2>/dev/null||echo '?') proc, $(du -h "$f"|cut -f1), $(date -r "$f" '+%m-%d %H:%M'))${N}"; done; p; }
do15() { clear; echo -e "${W}═══ 15. ВИДАЛИТИ БЕКАП ═══${N}\n"; ls ~/.pm2/dump.pm2.* 2>/dev/null|xargs -r -n1 basename|nl; read -p "  ім'я: " n; [ -f ~/.pm2/"$n" ]&&rm ~/.pm2/"$n"&&echo "✅"; p; }
do16() { clear; echo -e "${W}═══ 16. ВМІСТ DUMP (jq) ═══${N}\n"; jq -r '.[]|"  \(.name) | \(.pm2_env.pm_exec_interpreter // "?") | \(.pm2_env.pm_exec_path // "?")"' ~/.pm2/dump.pm2 2>/dev/null; p; }
do17() { clear; echo -e "${W}═══ 17. DUMP → CSV ═══${N}\n"; echo "name,interpreter,status,path" > /tmp/cybra-dump.csv; jq -r '.[]|"\(.name),\(.pm2_env.pm_exec_interpreter // "?"),\(.pm2_env.status // "?"),\(.pm2_env.pm_exec_path // "?")"' ~/.pm2/dump.pm2 2>/dev/null>>/tmp/cybra-dump.csv; echo "  ✅ /tmp/cybra-dump.csv ($(wc -l < /tmp/cybra-dump.csv) рядків)"; head -5 /tmp/cybra-dump.csv|sed 's/^/  /'; p; }
do18() { clear; echo -e "${W}═══ 18. RAM / CPU / DISK ═══${N}\n"; echo -e "${C}RAM:${N}"; free -h|head -2; echo ""; echo -e "${C}CPU load:${N}"; cat /proc/loadavg; echo ""; echo -e "${C}Disk:${N}"; df -h ~|tail -1; p; }

# ═══════════════ 19: REDIS ═══════════════
do19() { clear; echo -e "${W}═══ 19. REDIS ═══${N}\n"; echo "  keys: $(redis-cli dbsize 2>/dev/null||echo '?')"; echo ""; redis-cli --scan --pattern 'cybra:*' 2>/dev/null|head -20|sed 's/^/  ● /'; p; }

# ═══════════════ 20-28: МОДУЛІ ═══════════════
do20() { clear; echo -e "${W}═══ 20. МОДУЛІ — ВСІ ═══${N}\n"; local a=() i=1; for d in "$CYBRA/modules"/*/; do [ -d "$d" ]||continue; local n=$(basename "$d"); if [ -f "$d/manifest.json" ]; then [ "$(jq -r '.stub//false' "$d/manifest.json" 2>/dev/null)" = "true" ]&&continue; fi; local e=$(de "$d"); [ -z "$e" ]&&m="${R}[no]${N}"||m="${G}[${e%%|*}]${N}"; echo -e "  ${G}$i)${N} $n $m"; a+=("$n"); i=$((i+1)); done; p; }
do21() { clear; echo -e "${W}═══ 21. МОДУЛІ — ПО КАТЕГОРІЯХ ═══${N}\n"; for c in $(find "$CYBRA/modules" -maxdepth 2 -name manifest.json 2>/dev/null|xargs -r jq -r 'select(.stub!=true)|.category//"?"' 2>/dev/null|sort -u); do local cnt=$(find "$CYBRA/modules" -maxdepth 2 -name manifest.json 2>/dev/null|xargs -r jq -r --arg c "$c" 'select(.stub!=true and .category==$c)|.name' 2>/dev/null|wc -l); echo -e "  ● $c ${D}($cnt)${N}"; done; p; }
do22() { clear; echo -e "${W}═══ 22. ЗАПУСК МОДУЛЯ ═══${N}\n"; read -p "  назва: " n; [ -z "$n" ]&&return; local d="$CYBRA/modules/$n" e=$(de "$CYBRA/modules/$n"); [ -z "$e" ]&&{ echo "no entry"; p; return; }; local it="${e%%|*}" pt="${e##*|}"; pm2 start "$d/$pt" --name "$n" --interpreter "$it" --max-memory-restart 100M 2>&1|tail -2; sleep 2; pm2 list|grep "$n"; p; }
do23() { clear; echo -e "${W}═══ 23. ПРИКРІПИТИ МОДУЛЬ ═══${N}\n"; read -p "  назва: " n; [ -z "$n" ]&&return; local d="$CYBRA/modules/$n" e=$(de "$CYBRA/modules/$n"); [ -z "$e" ]&&{ echo "no entry"; p; return; }; read -p "  alias: " al; [ -z "$al" ]&&al="$n"; read -p "  опис: " ds; jq --arg a "$al" --arg p "$d" --arg en "${e##*|}" --arg it "${e%%|*}" --arg d "$ds" '.attached[$a]={"path":$p,"entry":$en,"interp":$it,"desc":$d}' "$REG">"$REG.t"&&mv "$REG.t" "$REG"; echo "✅ $al"; p; }
do24() { clear; echo -e "${W}═══ 24. ПРИКРІПЛЕНІ ═══${N}\n"; local i=1; for al in $(jq -r '.attached|keys[]' "$REG" 2>/dev/null); do echo -e "  ${G}$i)${N} ${W}$al${N} ${D}[$(jq -r --arg a "$al" '.attached[$a].interp' "$REG")]${N} $(jq -r --arg a "$al" '.attached[$a].desc' "$REG")"; i=$((i+1)); done; p; }
do25() { clear; echo -e "${W}═══ 25. ПРИКРІПЛЕНІ — RUN ═══${N}\n"; local a=() i=1; for al in $(jq -r '.attached|keys[]' "$REG" 2>/dev/null); do echo -e "  ${G}$i)${N} $al"; a+=("$al"); i=$((i+1)); done; read -p "  #: " n; local al="${a[$((n-1))]}"; [ -z "$al" ]&&{ p; return; }; local pth=$(jq -r --arg a "$al" '.attached[$a].path' "$REG")/$(jq -r --arg a "$al" '.attached[$a].entry' "$REG"); local it=$(jq -r --arg a "$al" '.attached[$a].interp' "$REG"); pm2 start "$pth" --name "$al" --interpreter "$it" --max-memory-restart 100M 2>&1|tail -2; p; }
do26() { clear; echo -e "${W}═══ 26. ПРИКРІПЛЕНІ — TEST ═══${N}\n"; local a=() i=1; for al in $(jq -r '.attached|keys[]' "$REG" 2>/dev/null); do echo -e "  ${G}$i)${N} $al"; a+=("$al"); i=$((i+1)); done; read -p "  #: " n; local al="${a[$((n-1))]}"; [ -z "$al" ]&&{ p; return; }; local pth=$(jq -r --arg a "$al" '.attached[$a].path' "$REG"); local en=$(jq -r --arg a "$al" '.attached[$a].entry' "$REG"); local it=$(jq -r --arg a "$al" '.attached[$a].interp' "$REG"); echo "▶ 5s:"; (cd "$pth"&&timeout 5 bash -c "$it $en") 2>&1|head -15; p; }
do27() { clear; echo -e "${W}═══ 27. ПРИКРІПЛЕНІ — DETACH ═══${N}\n"; local a=() i=1; for al in $(jq -r '.attached|keys[]' "$REG" 2>/dev/null); do echo -e "  ${G}$i)${N} $al"; a+=("$al"); i=$((i+1)); done; read -p "  #: " n; local al="${a[$((n-1))]}"; [ -n "$al" ]&&jq --arg a "$al" 'del(.attached[$a])' "$REG">"$REG.t"&&mv "$REG.t" "$REG"&&echo "✅"; p; }
do28() { clear; echo -e "${W}═══ 28. АЛІАСИ ═══${N}\n"; grep '^alias cybra' ~/.bashrc 2>/dev/null|sed 's/^/  /'; p; }

# ═══════════════ 29-34: AI TASKS ═══════════════
do29() { clear; echo -e "${W}═══ 29. AI — SUBMIT ═══${N}\n"; read -p "  type (module-fix/new/fidic): " t; read -p "  target: " g; read -p "  desc: " d; [ -n "$g" ]&&bash "$CYBRA/ai-tasks/ai-task.sh" submit "${t:-module-fix}" "$g" "$d"; p; }
do30() { clear; echo -e "${W}═══ 30. AI — LIST ═══${N}\n"; bash "$CYBRA/ai-tasks/ai-task.sh" list; p; }
do31() { clear; echo -e "${W}═══ 31. AI — VOTE ═══${N}\n"; bash "$CYBRA/ai-tasks/ai-task.sh" list; read -p "  id: " id; read -p "  for/against: " dir; [ -n "$id" ]&&bash "$CYBRA/ai-tasks/ai-task.sh" vote "$id" "${dir:-for}"; p; }
do32() { clear; echo -e "${W}═══ 32. AI — APPROVE ALL ═══${N}"; bash "$CYBRA/ai-tasks/ai-task.sh" approve-all; p; }
do33() { clear; echo -e "${W}═══ 33. AI — APPLY ═══${N}\n"; ls "$CYBRA/ai-tasks/approved/"*.json 2>/dev/null|xargs -r -n1 basename|sed 's/.json//'|nl; read -p "  id: " id; [ -n "$id" ]&&bash "$CYBRA/autofix-engine/bin/apply.sh" "$id"; p; }
do34() { clear; echo -e "${W}═══ 34. AI — СТАТИСТИКА ═══${N}\n"; for d in inbox approved executed failed; do echo "  $d: $(ls "$CYBRA/ai-tasks/$d"/*.json 2>/dev/null|wc -l)"; done; p; }

# ═══════════════ 35-42: BINARY BOX ═══════════════
do35() { clear; echo -e "${W}═══ 35. BOX — LIST ═══${N}\n"; bash "$CYBRA/binary-box/bin/box.sh" list; p; }
do36() { clear; echo -e "${W}═══ 36. BOX — ADD ═══${N}\n"; read -p "  шлях: " s; read -p "  ключ: " k; [ -n "$s" ]&&bash "$CYBRA/binary-box/bin/box.sh" add "$s" "${k:-}"; p; }
do37() { clear; echo -e "${W}═══ 37. BOX — HEALTH ═══${N}\n"; bash "$CYBRA/binary-box/bin/box.sh" health; p; }
do38() { clear; echo -e "${W}═══ 38. BOX — PRUNE ═══${N}\n"; bash "$CYBRA/binary-box/bin/box.sh" prune; p; }
do39() { clear; echo -e "${W}═══ 39. BOX — SYNC GitHub ═══${N}\n"; bash "$CYBRA/binary-box/bin/box.sh" sync; p; }
do40() { clear; echo -e "${W}═══ 40. BOX — GIT INIT ═══${N}\n"; bash "$CYBRA/binary-box/bin/box.sh" git-init; p; }
do41() { clear; echo -e "${W}═══ 41. BOX — REPAIRE ═══${N}\n"; for k in $(jq -r '.items|keys[]' "$CYBRA/binary-box/manifest.json" 2>/dev/null); do [ ! -f "$CYBRA/binary-box/data/$k" ]&&{ echo "❌ $k"; (cd "$CYBRA/binary-box"&&git checkout HEAD -- "data/$k" 2>/dev/null&&echo "  ✅"); }; done; bash "$CYBRA/binary-box/bin/box.sh" health; p; }
do42() { clear; echo -e "${W}═══ 42. BOX — USAGE ═══${N}\n"; bash "$CYBRA/binary-box/bin/box.sh" usage; echo ""; du -sh "$CYBRA/binary-box/data" 2>/dev/null; p; }

# ═══════════════ 43-49: INFRA ═══════════════
do43() { clear; echo -e "${W}═══ 43. FORTRESS ═══${N}"; [ -x "$CYBRA/cybra-fortress-v2.sh" ]&&bash "$CYBRA/cybra-fortress-v2.sh" 2>&1|tail -15||echo "❌"; p; }
do44() { clear; echo -e "${W}═══ 44. AUTO-PERMS ═══${N}"; [ -x "$CYBRA/cybra-perms.sh" ]&&bash "$CYBRA/cybra-perms.sh" 2>&1|tail -15||echo "❌"; p; }
do45() { clear; echo -e "${W}═══ 45. CONTROLLER ═══${N}\n"; echo "  Рівень: L$(cat "$CYBRA/.ctl.state" 2>/dev/null||echo '?')"; echo ""; tail -15 "$CYBRA/.ctl.log" 2>/dev/null|sed 's/^/  /'; p; }
do46() { clear; echo -e "${W}═══ 46. FORCE LEVEL ═══${N}\n"; echo "  1 SLEEP 2 CRIT 3 LOW 4 NORMAL 5 HIGH 6 TURBO 7 MAX"; read -p "  [1-7]: " l; [[ "$l" =~ ^[1-7]$ ]]&&bash "$CYBRA/cybra-controller-v2.sh" --force-level "$l" 2>&1|head -15; p; }
do47() { clear; echo -e "${W}═══ 47. NEURO статус ═══${N}\n"; for f in bin/cybra_neuro_controller.py bin/cybra_evolution_controller.py bin/cybra_oracle_controller.py bin/cybra_resurrection_controller.py; do [ -f "$CYBRA/$f" ]&&echo "  ✅ $f"||echo "  ❌ $f"; done; echo ""; pm2 list 2>/dev/null|grep -E "neuro|evolution|oracle|resurrect"|sed 's/^/  /'; p; }
do48() { clear; echo -e "${W}═══ 48. NEURO RESTART ═══${N}"; pm2 restart cybra-neuro cybra-evolution 2>&1|tail -3; sleep 2; pm2 list|grep -E "neuro|evolution"; p; }
do49() { clear; echo -e "${W}═══ 49. CONTRACTS ═══${N}\n"; local f="$CYBRA/modules/autodopomoga/contracts.json"; [ -f "$f" ]||{ echo "❌"; p; return; }; export CYBRA; for k in $(jq -r 'keys[]|select(startswith("_")|not)' "$f" 2>/dev/null); do local h=$(jq -r --arg k "$k" '.[$k].health//""' "$f" 2>/dev/null); if [ -n "$h" ]&&bash -c "$h" >/dev/null 2>&1; then echo -e "  ${G}✅${N} $k"; else echo -e "  ${R}❌${N} $k"; fi; done; p; }
do50() { clear; echo -e "${W}═══ 50. FULL STATUS ═══${N}\n"; pm2 list 2>/dev/null|tail -n +2|head -20; echo ""; free -h|head -2; echo ""; echo "Dump: $(du -h ~/.pm2/dump.pm2 2>/dev/null|cut -f1)"; echo "Redis: $(redis-cli dbsize 2>/dev/null||echo '?') keys"; echo "Box: $(bash "$CYBRA/binary-box/bin/box.sh" usage 2>/dev/null)"; p; }

# ═══════════════ MAIN ═══════════════
while true; do
    clear
    echo -e "${C}╔══════════════════════════════════════════════════╗${N}"
    echo -e "${C}║${W}   CYBRA — Unified Menu 1–50                     ${C}║${N}"
    echo -e "${C}╚══════════════════════════════════════════════════╝${N}"
    status
    echo ""
    echo -e "  ${W}─── ПРОЦЕСИ ───${N}"
    echo -e "  ${G}[1]${N} Сканувати      ${G}[2]${N} Пошук          ${G}[3]${N} Запустити файл"
    echo -e "  ${G}[4]${N} Зупинити        ${G}[5]${N} Restart all    ${G}[6]${N} Delete"
    echo -e "  ${G}[7]${N} PM2 list        ${G}[8]${N} Logs           ${G}[9]${N} Fix PM2"
    echo ""
    echo -e "  ${W}─── ФІКСАЦІЯ / ДАМПИ ───${N}"
    echo -e "  ${G}[10]${N} ${C}SAVE${N} dump      ${G}[11]${N} Бекап          ${G}[12]${N} Restore"
    echo -e "  ${G}[13]${N} ${Y}ПІДНЯТИ ВСЕ${N}    ${G}[14]${N} Список бекапів ${G}[15]${N} Видалити"
    echo -e "  ${G}[16]${N} Вміст dump      ${G}[17]${N} Dump→CSV       ${G}[18]${N} RAM/CPU/Disk"
    echo -e "  ${G}[19]${N} Redis keys"
    echo ""
    echo -e "  ${W}─── МОДУЛІ ───${N}"
    echo -e "  ${G}[20]${N} Всі             ${G}[21]${N} По категоріях  ${G}[22]${N} Запуск"
    echo -e "  ${G}[23]${N} Прикріпити      ${G}[24]${N} Прикріплені    ${G}[25]${N} Attached run"
    echo -e "  ${G}[26]${N} Attached test   ${G}[27]${N} Detach         ${G}[28]${N} Аліаси"
    echo ""
    echo -e "  ${W}─── AI TASKS ───${N}"
    echo -e "  ${G}[29]${N} Submit          ${G}[30]${N} List           ${G}[31]${N} Vote"
    echo -e "  ${G}[32]${N} Approve all     ${G}[33]${N} Apply          ${G}[34]${N} Stats"
    echo ""
    echo -e "  ${W}─── BINARY BOX 65MB ───${N}"
    echo -e "  ${G}[35]${N} List            ${G}[36]${N} Add            ${G}[37]${N} Health"
    echo -e "  ${G}[38]${N} Prune           ${G}[39]${N} Sync GitHub    ${G}[40]${N} Git init"
    echo -e "  ${G}[41]${N} Repaire         ${G}[42]${N} Usage"
    echo ""
    echo -e "  ${W}─── INFRA ───${N}"
    echo -e "  ${G}[43]${N} Fortress        ${G}[44]${N} Auto-perms     ${G}[45]${N} Controller"
    echo -e "  ${G}[46]${N} Force level     ${G}[47]${N} NEURO status   ${G}[48]${N} NEURO restart"
    echo -e "  ${G}[49]${N} Contracts       ${G}[50]${N} ${Y}Full status${N}"
    echo ""
    echo -e "  ${R}[0]${N} Вихід"
    echo ""
    read -p "  → " choice
    case "$choice" in
        1) do1;; 2) do2;; 3) do3;; 4) do4;; 5) do5;; 6) do6;; 7) do7;; 8) do8;; 9) do9;;
        10) do10;; 11) do11;; 12) do12;; 13) do13;; 14) do14;; 15) do15;; 16) do16;; 17) do17;; 18) do18;; 19) do19;;
        20) do20;; 21) do21;; 22) do22;; 23) do23;; 24) do24;; 25) do25;; 26) do26;; 27) do27;; 28) do28;;
        29) do29;; 30) do30;; 31) do31;; 32) do32;; 33) do33;; 34) do34;;
        35) do35;; 36) do36;; 37) do37;; 38) do38;; 39) do39;; 40) do40;; 41) do41;; 42) do42;;
        43) do43;; 44) do44;; 45) do45;; 46) do46;; 47) do47;; 48) do48;; 49) do49;; 50) do50;;
        0) echo "Бувай"; exit 0;;
        *) sleep 1;;
    esac
done
