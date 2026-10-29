#!/data/data/com.termux/files/usr/bin/bash
[ -f "$HOME/CYBRA/modules/module_101_module_101/main.sh" ] || { echo "missing"; exit 2; }
bash "$HOME/CYBRA/modules/module_101_module_101/main.sh" "$@"
