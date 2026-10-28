#!/data/data/com.termux/files/usr/bin/bash
set -u
MODULE="$1"; shift
[ -f "$MODULE" ] || { echo "missing"; exit 2; }
[ $# -gt 0 ] && ARGS=("$@") || ARGS=("list")
bash "$MODULE" "${ARGS[@]}" </dev/null 2>&1
exit $?
