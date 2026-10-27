#!/data/data/com.termux/files/usr/bin/bash
set -u
M="$1"; shift
[ -f "$M" ] || { echo "missing"; exit 2; }
[ $# -gt 0 ] && A=("$@") || A=("help")
bash "$M" "${A[@]}" </dev/null 2>&1
exit $?
