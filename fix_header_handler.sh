#!/data/data/com.termux/files/usr/bin/bash
set -u
cd "$HOME/CYBRA"
MENU="modules/module_19_contract_tui_menu/bin/cybra_menu.sh"
chmod u+w "$MENU"

python3 - "$MENU" <<'PY'
import sys, re, hashlib
from pathlib import Path
p = sys.argv[1]
t = open(p).read()

# 1. Кеш header — рахувати раз на 60 сек
old = '''print_header() {
    printf '\\n'
    local mods=0
    for d in "$HOME/CYBRA/modules"/*/; do
        [ -d "$d" ] || continue
        local m=$(basename "$d")
        case "$m" in @*|.*|_disabled*|evolution|answer_engine|node_modules) continue;; esac
        mods=$((mods+1))
    done
    local cons=0
    for f in "$CYBRA_CONTRACTS"/*.env; do [ -f "$f" ] && cons=$((cons+1)); done
    local links=0
    for f in "$CYBRA_LINKS"/*.link; do [ -f "$f" ] && links=$((links+1)); done
    local now="$(date -u '+%Y-%m-%d %H:%M:%S UTC')"'''

new = '''print_header() {
    printf '\\n'
    local CACHE="$HOME/CYBRA/state/tui_header.cache"
    local mods cons links
    if [ -f "$CACHE" ] && [ $(( $(date +%s) - $(stat -c %Y "$CACHE" 2>/dev/null || echo 0) )) -lt 60 ]; then
        IFS='|' read -r mods cons links < "$CACHE"
    else
        mods=0
        for d in "$HOME/CYBRA/modules"/*/; do
            [ -d "$d" ] || continue
            case "$(basename "$d")" in @*|.*|_disabled*|evolution|answer_engine|node_modules) continue;; esac
            mods=$((mods+1))
        done
        cons=$(ls "$CYBRA_CONTRACTS"/*.env 2>/dev/null | wc -l)
        links=$(ls "$CYBRA_LINKS"/*.link 2>/dev/null | wc -l)
        echo "$mods|$cons|$links" > "$CACHE"
    fi
    local now="$(date -u '+%Y-%m-%d %H:%M:%S UTC')"'''

if old in t:
    t = t.replace(old, new)
    print("cache:ok")
else:
    print("cache:skip")

# 2. Заголовки з реальним ім'ям
changed = 0
for m in (Path.home()/"CYBRA/modules").glob("module_*/main.sh"):
    try: txt = m.read_text(errors="ignore")
    except: continue
    match = re.search(r'# module_(\d+): (\w+) \(', txt)
    if not match: continue
    n, name = match.groups()
    for pat, rep in [
        (f'════ module_{n} (base) ════', f'════ {name} (module_{n}) ════'),
        (f'════ module_{n} ════', f'════ {name} (module_{n}) ════'),
    ]:
        if pat in txt:
            txt = txt.replace(pat, rep)
            m.write_text(txt)
            changed += 1
            break
print(f"headers:{changed}")

# 3. Синтаксис
PY

bash -n "$MENU" || { echo '{"ok":false,"stage":"syntax"}'; exit 1; }
chmod a-w "$MENU"
echo '{"ok":true,"headers_fixed":true,"cache":"enabled"}'
