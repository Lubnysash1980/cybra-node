#!/data/data/com.termux/files/usr/bin/bash
cd ~/CYBRA
. barmenu/lib/colors.sh

while true; do
  clear
  echo -e "${CYAN}╔══════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║   🏛️  CYBRA AUTO-MENU  v4.0                 ║${NC}"
  echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}"
  echo ""
  echo "──── СТАТУС ────"
  for m in cybra-pool cybra-brain parliament redis mock-ai; do
    s=$(pm2 jlist 2>/dev/null | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin); m=[x for x in d if x['name']=='$m']
    print(m[0]['pm2_env']['status'] if m else 'missing')
except: print('missing')
")
    case "$s" in
      online) echo -e "  ${GREEN}●${NC} $m" ;;
      missing) echo -e "  ${RED}●${NC} $m" ;;
      *) echo -e "  ${YELLOW}●${NC} $m ($s)" ;;
    esac
  done
  echo ""
  echo "──── МЕНЮ ────"
  python3 -c "
import json
for it in json.load(open('barmenu/menu.json'))['items']:
    print(f\"  {it['id']:>2}) {it['label']}\")
"
  echo "   0) Вихід"
  echo ""
  read -p "Обери: " choice
  [ "$choice" = "0" ] || [ -z "$choice" ] && exit 0
  action=$(python3 -c "
import json
for it in json.load(open('barmenu/menu.json'))['items']:
    if it['id']=='$choice': print(it['action']); break
")
  [ -f "barmenu/actions/$action.sh" ] && bash "barmenu/actions/$action.sh"
  echo ""
  read -p "Enter..."
done
