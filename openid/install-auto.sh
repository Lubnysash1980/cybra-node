#!/data/data/com.termux/files/usr/bin/bash

set -e

DIR="$HOME/CYBRA/openid"
APP="cybra-openid"

echo "================================"
echo "      CYBRA OPEN ID AUTO"
echo "================================"

cd "$DIR"

# 1. Перевірка файлів
if [ ! -f server.js ] || [ ! -f .env ]; then
    echo "[ERROR] server.js або .env відсутній"
    exit 1
fi

chmod 600 .env

# 2. Перевірка конфігурації
node -e '
require("dotenv").config();
const keys = [
"BASE_URL",
"GITHUB_CLIENT_ID",
"GITHUB_CLIENT_SECRET",
"JWT_SECRET"
];
let failed = false;
for (const k of keys) {
 const ok = !!process.env[k];
 console.log(k + ": " + (ok ? "OK" : "MISSING"));
 if (!ok) failed = true;
}
if (failed) process.exit(1);
'

# 3. Залежності
echo "[1/5] Installing dependencies..."
npm install

# 4. PM2
if ! command -v pm2 >/dev/null 2>&1; then
    npm install -g pm2
fi

# 5. Запуск окремої ноди
echo "[2/5] Starting CYBRA OPEN ID..."

if pm2 describe "$APP" >/dev/null 2>&1; then
    pm2 restart "$APP" --update-env
else
    pm2 start server.js \
      --name "$APP" \
      --cwd "$DIR" \
      --time
fi

# 6. Збереження PM2
echo "[3/5] Saving PM2 state..."
pm2 save

# 7. Перевірка
echo "[4/5] Checking API..."

sleep 3

if curl -fsS http://127.0.0.1:8787/health; then
    echo
    echo "[SUCCESS] CYBRA OPEN ID ONLINE"
else
    echo
    echo "[ERROR] API unavailable"
    pm2 logs "$APP" --lines 30 --nostream
    exit 1
fi

# 8. Підсумок
echo
echo "================================"
echo " CYBRA OPEN ID INSTALLED"
echo "================================"

pm2 status

echo
echo "Useful commands:"
echo "pm2 logs cybra-openid"
echo "pm2 restart cybra-openid"
echo "pm2 status"
echo "pm2 save"

