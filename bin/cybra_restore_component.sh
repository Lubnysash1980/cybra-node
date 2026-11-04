#!/data/data/com.termux/files/usr/bin/bash
set -u
CYBRA="$HOME/CYBRA"
case "${1:-all}" in
  all) exec "$CYBRA/bin/cybra_autorestore.sh" ;;
  *)   exec "$CYBRA/bin/cybra_autorestore.sh" "$1" ;;
esac
