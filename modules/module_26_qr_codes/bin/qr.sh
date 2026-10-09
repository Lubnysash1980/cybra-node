#!/data/data/com.termux/files/usr/bin/bash
QR_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$QR_ROOT/data"

qr_gen() {
    local text="$1" out="${2:-}"
    if command -v qrencode >/dev/null 2>&1; then
        if [ -n "$out" ]; then
            qrencode -o "$out" "$text"
            echo "OK: $out"
        else
            printf '%s' "$text" | qrencode -t ANSIUTF8
        fi
    else
        echo "ERR: qrencode not installed"
        echo "Text: $text"
        return 1
    fi
}

qr_gen_link() {
    local cid="$1" role="$2"
    local lid
    lid="$(grep "^${role}_LINK_ID=" "$HOME/CYBRA/modules/module_19_contract_tui_menu/contracts/$cid.env" 2>/dev/null | cut -d= -f2)"
    [ -z "$lid" ] && { echo "ERR: link not found"; return 1; }
    qr_gen "cybra://$cid/$role/$lid" "$QR_ROOT/data/${cid}_${role}.png"
}

qr_gen_file() {
    local text="$1" out="$2"
    qrencode -o "$out" "$text" && echo "OK: $out"
}
