#!/data/data/com.termux/files/usr/bin/bash
# cybra_contract_debug — діагностика: що працює, що зламано, як фіксити

CYBRA="$HOME/CYBRA"
MOD="$CYBRA/modules/module_19_contract_tui_menu"
MENU="$MOD/bin/cybra_menu.sh"

G=$'\033[92m'; R=$'\033[91m'; Y=$'\033[93m'; C=$'\033[96m'; B=$'\033[1m'; Z=$'\033[0m'

ok()   { printf "  ${G}[✓]${Z} %s\n" "$1"; }
bad()  { printf "  ${R}[✗]${Z} %s\n" "$1"; }
warn() { printf "  ${Y}[!]${Z} %s\n" "$1"; }
info() { printf "  ${C}[i]${Z} %s\n" "$1"; }

FIXES=()
add_fix() { FIXES+=("$1"); }

echo
echo "${B}═══ CYBRA CONTRACT DEBUG ═══${Z}"
echo "  $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo

# ─────── 1. Структура ───────
echo "${C}─── 1. STRUCTURE ───${Z}"
for d in "$CYBRA" "$MOD" "$MOD/bin" "$MOD/contracts" "$CYBRA/bin" "$CYBRA/logs"; do
    if [ -d "$d" ]; then ok "dir $d"
    else bad "dir missing: $d"; add_fix "mkdir -p '$d'"; fi
done

for f in "$MENU" "$CYBRA/bin/cybra_qr.sh" "$CYBRA/bin/cybra_binmix" "$CYBRA/bin/cybra_autopilot"; do
    if [ -f "$f" ]; then
        [ -x "$f" ] && ok "exec $f" || { warn "not executable: $f"; add_fix "chmod +x '$f'"; }
    else
        bad "file missing: $f"; add_fix "створити '$f'"
    fi
done

# ─────── 2. Синтаксис скриптів ───────
echo
echo "${C}─── 2. SYNTAX CHECK ───${Z}"
for sh in "$CYBRA/ai/cybra_ai_executor.sh" "$MENU" "$CYBRA/bin/cybra_qr.sh" \
          "$CYBRA/bin/cybra_binmix" "$CYBRA/bin/cybra_autopilot"; do
    if [ ! -f "$sh" ]; then warn "skip (missing): $sh"; continue; fi
    if bash -n "$sh" 2>/dev/null; then
        ok "syntax OK: $(basename "$sh")"
    else
        bad "syntax BROKEN: $(basename "$sh")"
        add_fix "bash -n '$sh'  → подивитись помилку і виправити"
    fi
done

# ─────── 3. Функції меню ───────
echo
echo "${C}─── 3. MENU FUNCTIONS ───${Z}"
declare -A ITEMS=(
  [1]=action_create [2]=action_list [3]=action_status [4]=action_gen_links
  [5]=action_confirm [6]=action_debug [7]=action_dual_lic [8]=action_creation
  [9]=action_hardening [11]=action_invoice_new [12]=action_invoice_add
  [13]=action_invoice_show [14]=action_invoice_fin [15]=action_pii_export
  [16]=action_export_all [17]=action_pii_hash [18]=action_refund_dec
  [19]=action_refund_to [20]=action_refund_st [21]=action_refund_cond
)
MISSING_FN=0
for n in "${!ITEMS[@]}"; do
    fn="${ITEMS[$n]}"
    if grep -q "^${fn}()" "$MENU" 2>/dev/null; then
        ok "[$n] $fn"
    else
        bad "[$n] $fn MISSING"
        MISSING_FN=$((MISSING_FN+1))
        add_fix "додати функцію ${fn}() у $MENU"
    fi
done

# ─────── 4. Залежності ───────
echo
echo "${C}─── 4. DEPENDENCIES ───${Z}"
for cmd in bash python3 git jq qrencode; do
    if command -v "$cmd" >/dev/null 2>&1; then
        ok "cmd: $cmd ($(command -v $cmd))"
    else
        warn "cmd missing: $cmd"
        case "$cmd" in
            jq)       add_fix "pkg install -y jq" ;;
            qrencode) add_fix "pkg install -y libqrencode" ;;
            python3)  add_fix "pkg install -y python" ;;
            git)      add_fix "pkg install -y git" ;;
        esac
    fi
done

# ─────── 5. Git ───────
echo
echo "${C}─── 5. GIT ───${Z}"
if [ -d "$CYBRA/.git" ]; then
    ok "git repo"
    if git -C "$CYBRA" remote -v | grep -q origin; then
        ok "remote origin: $(git -C "$CYBRA" remote get-url origin)"
    else
        bad "no remote"
        add_fix "git -C '$CYBRA' remote add origin https://github.com/USER/REPO.git"
    fi
    DIRTY=$(git -C "$CYBRA" status --porcelain | wc -l)
    [ "$DIRTY" -eq 0 ] && ok "working tree clean" || warn "uncommitted: $DIRTY files"
else
    bad "not a git repo"
    add_fix "cd '$CYBRA' && git init -b main"
fi

# ─────── 6. Токен ───────
echo
echo "${C}─── 6. GITHUB TOKEN ───${Z}"
if [ -f "$CYBRA/.github_token" ]; then
    TSIZE=$(wc -c < "$CYBRA/.github_token")
    if [ "$TSIZE" -ge 40 ]; then
        ok "token present ($TSIZE chars)"
        if [ "$TSIZE" -lt 45 ]; then
            warn "token may be placeholder — перевір curl -H 'Authorization: token \$(cat .github_token)' https://api.github.com/user"
        fi
    else
        bad "token looks invalid ($TSIZE chars, очікується 40+)"
        add_fix "echo 'ghp_РЕАЛЬНИЙ' > '$CYBRA/.github_token' && chmod 600 '$CYBRA/.github_token'"
    fi
else
    bad "no .github_token"
    add_fix "створити токен на github.com/settings/tokens → записати у '$CYBRA/.github_token'"
fi

# ─────── 7. JSON файли ───────
echo
echo "${C}─── 7. JSON FILES ───${Z}"
for j in "$CYBRA/chain.json" "$CYBRA/parliament.json" \
         "$MOD/contracts/contracts.json"; do
    if [ -f "$j" ]; then
        if python3 -c "import json;json.load(open('$j'))" 2>/dev/null; then
            ok "valid JSON: $(basename "$j")"
        else
            bad "BROKEN JSON: $j"
            add_fix "python3 -m json.tool '$j' > /tmp/fixed.json && mv /tmp/fixed.json '$j'"
        fi
    else
        info "missing (optional): $j"
    fi
done

# ─────── 8. Процеси pm2 ───────
echo
echo "${C}─── 8. PM2 ───${Z}"
if command -v pm2 >/dev/null 2>&1; then
    ok "pm2 available"
    pm2 list 2>/dev/null | grep -qE 'online' && ok "pm2 processes running" || warn "pm2: no online processes"
else
    warn "pm2 not installed"
    add_fix "pkg install -y nodejs && npm i -g pm2"
fi

# ─────── 9. Швидкий self-test ───────
echo
echo "${C}─── 9. QUICK SELF-TEST ───${Z}"

# 9.1: qr
if command -v qrencode >/dev/null 2>&1; then
    qr_out=$(mktemp --suffix=.png)
    if qrencode -o "$qr_out" -s 4 "selftest" 2>/dev/null && [ -s "$qr_out" ]; then
        ok "qrencode works"
    else
        bad "qrencode broken"
        add_fix "перевстанови: pkg install -y libqrencode"
    fi
    rm -f "$qr_out"
else
    skip_msg="qrencode відсутній"
    warn "$skip_msg"
fi

# 9.2: json roundtrip
if python3 -c "
import json, tempfile, os
d={'a':1,'b':[1,2,3],'c':{'x':'y'}}
f=tempfile.NamedTemporaryFile(delete=False,mode='w')
json.dump(d,f); f.close()
json.load(open(f.name)); os.unlink(f.name)
" 2>/dev/null; then
    ok "python json roundtrip"
else
    bad "python json broken"
    add_fix "pkg install -y python"
fi

# 9.3: write permission
TESTW="$CYBRA/.tests/.write_test"
mkdir -p "$CYBRA/.tests"
if touch "$TESTW" 2>/dev/null; then
    ok "write permission: $CYBRA"
    rm -f "$TESTW"
else
    bad "no write permission in $CYBRA"
    add_fix "перевір права: ls -ld '$CYBRA'"
fi

# ─────── FIX PLAN ───────
echo
echo "${B}═══ FIX PLAN ═══${Z}"
if [ "${#FIXES[@]}" -eq 0 ]; then
    echo "  ${G}✅ Все працює. Нічого фіксити не треба.${Z}"
else
    echo "  ${Y}Треба виконати ${#FIXES[@]} дій:${Z}"
    echo
    i=1
    for fix in "${FIXES[@]}"; do
        printf "  %2d) %s\n" "$i" "$fix"
        i=$((i+1))
    done
    echo
    echo "  ${C}Порада:${Z} копіюй команди по одній, перевіряй після кожної."
fi
echo
