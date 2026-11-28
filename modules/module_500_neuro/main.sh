#!/data/data/com.termux/files/usr/bin/bash
set -u
ROOT="$HOME/CYBRA"
NEURO="$ROOT/modules/module_500_neuro/neuro.py"
while :; do
  clear
  printf '\033[36m═══ CYBRA NEURO — AI patch staging ═══\033[0m\n\n'
  python3 "$NEURO" status 2>&1
  printf '\n  1) Створити AI patch у staging\n'
  printf '  2) Передати patch до Parliament\n'
  printf '  3) Перевірити статус\n'
  printf '  0) Назад\n'
  read -r -p 'Вибір: ' choice
  case "$choice" in
    1)
      read -r -p 'Опиши задачу: ' task
      read -r -p 'Файли modules/module_*/... (через пробіл): ' files
      if [ -z "$task" ] || [ -z "$files" ]; then
        echo 'Потрібно вказати задачу та файли.'
      else
        # shellcheck disable=SC2206
        file_args=( $files )
        python3 "$NEURO" generate --task "$task" "${file_args[@]}"
      fi
      read -r -p 'Enter…' _
      ;;
    2)
      read -r -p 'PATCH_ID: ' patch_id
      [ -n "$patch_id" ] && python3 "$NEURO" propose "$patch_id"
      read -r -p 'Enter…' _
      ;;
    3)
      python3 "$NEURO" status
      read -r -p 'Enter…' _
      ;;
    4)
      read -r -p 'Ціль для NEURO (які функції/пункти додати): ' goal
      [ -n "$goal" ] && python3 "$NEURO" plan --goal "$goal"
      read -r -p 'Enter…' _
      ;;
    0) exit 0 ;;
    *) echo 'Невідомий пункт'; sleep 1 ;;
  esac
done
