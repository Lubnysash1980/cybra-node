#!/data/data/com.termux/files/usr/bin/bash
# Модуль 154: Менеджер посилань (Тунель)
CYBRA="$HOME/CYBRA"
SERVER_PY="$CYBRA/modules/module_119_qr_sign/server.py"
EVIDENCE_DIR="$CYBRA/modules/module_19_contract_tui_menu/evidence/"
LOG_FILE="$CYBRA/state/tunnel_out.log"

mkdir -p "$CYBRA/state"

while true; do
    clear
    echo "════════ 154. МЕНЕДЖЕР ПОСИЛАНЬ ════════"
    echo "1) Згенерувати лінк для MetaMask"
    echo "0) Назад"
    read -r -p "Вибір: " c
    case "$c" in
        1) 
            read -r -p "Введіть ID контракту (CID): " cid
            [ -z "$cid" ] && continue
            
            # Запускаємо сервер, якщо він не працює
            if ! curl -s http://localhost:8080 > /dev/null; then
                python3 "$SERVER_PY" "$EVIDENCE_DIR" 8080 > /dev/null 2>&1 &
                sleep 2
            fi
            
            echo "⏳ Створюю тунель через localhost.run..."
            rm -f "$LOG_FILE"
            ssh -R 80:localhost:8080 -o StrictHostKeyChecking=no -o ServerAliveInterval=30 nokey@localhost.run > "$LOG_FILE" 2>&1 &
            sleep 8
            
            BASE_LINK=$(grep -oE 'https://[a-zA-Z0-9.-]+\.lhr\.life' "$LOG_FILE" | head -1)
            if [ -n "$BASE_LINK" ]; then
                METAMASK_LINK=$(python3 -c "
import base64, json, time, sys, urllib.parse
url = sys.argv[1]; cid = sys.argv[2]
payload = {'v': 1, 'u': url, 'c': cid, 't': int(time.time())}
b64 = base64.urlsafe_b64encode(json.dumps(payload, separators=(',', ':')).encode()).decode().rstrip('=')
full_url = f'{url}?p={b64}'
print(f'https://link.metamask.io/dapp/{urllib.parse.quote(full_url, safe=\"\")}')
" "$BASE_LINK" "$cid")
                echo ""
                echo "════════════════════════════════════════════"
                echo "✅ ГОТОВЕ ПОСИЛАННЯ ДЛЯ METAMASK:"
                echo -e "\033[1;36m$METAMASK_LINK\033[0m"
                echo "════════════════════════════════════════════"
            else
                echo "⚠️ Не вдалося створити тунель. Перевірте інтернет."
            fi
            read -r -p "Enter..." _
            ;;
        0) exit 0 ;;
    esac
done
