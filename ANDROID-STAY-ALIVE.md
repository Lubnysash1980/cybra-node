# Щоб Android не вбивав CYBRA

1. **Termux:API** — встановити з F-Droid, дати дозволи
2. **Wake-lock** — `termux-wake-lock` (вже в cron)
3. **Battery optimization**:
   - Налаштування → Батарея → Оптимізація → Termux → **"Не оптимізувати"**
   - Xiaomi/MIUI: Security → Permissions → Autostart → Termux → ON
   - Samsung: Device care → Battery → Background usage limits → Never sleeping apps → додати Termux
   - Huawei: Battery → App launch → Termux → Manage manually → всі ON
4. **Notification** — Termux notification (ongoing) тримає процес
5. **Developer options → "Don't keep activities"** — OFF
6. **Перевірка**: `pm2 list` після блокування екрану на 10хв — має бути 20+ online
