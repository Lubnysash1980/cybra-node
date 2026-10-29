#!/data/data/com.termux/files/usr/bin/bash
[ -f "$HOME/CYBRA/modules/module_002_module_002/main.sh" ] || { echo "missing"; exit 2; }
bash "$HOME/CYBRA/modules/module_002_module_002/main.sh" "$@"
