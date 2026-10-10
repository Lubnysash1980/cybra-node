#!/data/data/com.termux/files/usr/bin/bash
SC_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$SC_ROOT/data"
mkdir -p "$OUT"

sc_photo() {
    local name="${1:-doc_$(date -u +%Y%m%dT%H%M%SZ)}"
    local file="$OUT/${name}.jpg"
    if ! command -v termux-camera-photo >/dev/null 2>&1; then
        echo "ERR: termux-camera-photo missing"
        echo "Install: pkg install termux-api"
        echo "Also install Termux:API app from F-Droid"
        return 1
    fi
    termux-camera-photo -c 0 "$file" && {
        echo "OK: $file"
        du -h "$file"
    } || echo "ERR: capture failed"
}

sc_ocr() {
    local file="$1"
    [ -f "$file" ] || { echo "ERR: file not found"; return 1; }
    local out="${file%.*}.txt"
    if command -v tesseract >/dev/null 2>&1; then
        tesseract "$file" "${file%.*}" -l ukr+eng 2>/dev/null && echo "OK: $out"
    else
        echo "WARN: tesseract missing"
        echo "Install: pkg install tesseract"
    fi
}

sc_pdf_to_text() {
    local pdf="$1"
    [ -f "$pdf" ] || { echo "ERR: file not found"; return 1; }
    local out="${pdf%.pdf}.txt"
    if command -v pdftotext >/dev/null 2>&1; then
        pdftotext -layout "$pdf" "$out" && echo "OK: $out"
    else
        echo "WARN: pdftotext missing"
        echo "Install: pkg install poppler"
    fi
}

sc_list() {
    printf 'PHOTOS:\n'
    ls -lh "$OUT"/*.jpg 2>/dev/null | tail -10
    printf '\nTEXTS:\n'
    ls -lh "$OUT"/*.txt 2>/dev/null | tail -10
}

sc_scan_pipeline() {
    local name="${1:-doc}"
    echo "1) Capturing..."
    local file="$OUT/${name}.jpg"
    sc_photo "$name" || return 1
    echo ""
    echo "2) OCR..."
    sc_ocr "$file"
    echo ""
    echo "3) Text ready at: $OUT/${name}.txt"
}
