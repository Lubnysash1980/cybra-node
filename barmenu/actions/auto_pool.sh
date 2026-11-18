#!/data/data/com.termux/files/usr/bin/bash
. barmenu/lib/colors.sh
clear
title "═══ 🚀 АВТО-СТВОРЕННЯ ПУЛУ ═══"
echo "Це створить пул БЕЗ участі гаманця (через Private Key)."
echo ""
read -p "Цільова ціна в USDT (напр. 1000): " TARGET
[ -z "$TARGET" ] && exit 0

# Тимчасово записуємо в .env
sed -i "s|^TARGET_USDT=.*|TARGET_USDT=$TARGET|" .env 2>/dev/null || echo "TARGET_USDT=$TARGET" >> .env

echo ""
info "Запуск авто-модуля..."
node bin/cybra_auto_pool.js
