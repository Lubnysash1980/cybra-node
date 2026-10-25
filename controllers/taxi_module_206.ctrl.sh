#!/data/data/com.termux/files/usr/bin/bash
set -u
M="$1"; shift
[ -f "$M" ] || { echo "❌ missing"; exit 2; }
bash -n "$M" 2>/dev/null || { echo "❌ syntax"; exit 3; }
[ $# -gt 0 ] && A=("$@") || A=("list")
bash "$M" "${A[@]}" </dev/null 2>&1; exit $?
