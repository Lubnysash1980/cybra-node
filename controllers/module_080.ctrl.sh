#!/data/data/com.termux/files/usr/bin/bash
[ -f "$HOME/CYBRA/modules/module_080_module_080/main.sh" ] || { echo "missing"; exit 2; }
bash "$HOME/CYBRA/modules/module_080_module_080/main.sh" "$@"
