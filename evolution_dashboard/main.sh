#!/data/data/com.termux/files/usr/bin/bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
CLI="$HERE/cybra-evolution.sh"
while :; do
  clear
  printf '\033[36m═══ CYBRA EVOLUTION DASHBOARD ═══\033[0m\n\n'
  printf '  1) Start / перевірити запуск\n'
  printf '  2) Status — короткий звіт\n'
  printf '  3) JSON — повний стан\n'
  printf '  4) Logs\n'
  printf '  5) Stop dashboard server\n'
  printf '  0) Назад\n'
  read -r -p 'Вибір: ' choice
  case "$choice" in
    1) bash "$CLI" start; read -r -p 'Enter…' _ ;;
    2) bash "$CLI" status; read -r -p 'Enter…' _ ;;
    3) bash "$CLI" json; read -r -p 'Enter…' _ ;;
    4) bash "$CLI" logs; read -r -p 'Enter…' _ ;;
    5) bash "$CLI" stop; read -r -p 'Enter…' _ ;;
    0) exit 0 ;;
    *) echo 'Невідомий пункт'; sleep 1 ;;
  esac
done
