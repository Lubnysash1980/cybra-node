#!/data/data/com.termux/files/usr/bin/bash
# QR генератор (для майбутньої реалізації)
cybra_qr_gen() {
    local text="$1"
    # Використовуємо qrencode якщо доступний
    if command -v qrencode >/dev/null 2>&1; then
        printf '%s' "$text" | qrencode -t ANSIUTF8
    else
        printf 'qrencode не встановлено.\n'
        printf 'Встанови: pkg install qrencode\n'
        printf 'Text: %s\n' "$text"
    fi
}
