#!/data/data/com.termux/files/usr/bin/bash
set -u
CYBRA="$HOME/CYBRA"; cd "$CYBRA/api" || exit 1
export CYBRA="$CYBRA"
# persistent JWT secret
SECRET_FILE="$CYBRA/state/api_jwt_secret.txt"
if [ ! -f "$SECRET_FILE" ]; then
  head -c 64 /dev/urandom | base64 > "$SECRET_FILE"
  chmod 600 "$SECRET_FILE"
fi
export CYBRA_JWT_SECRET="$(cat "$SECRET_FILE")"
exec python3 server.py
