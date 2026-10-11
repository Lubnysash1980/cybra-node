#!/data/data/com.termux/files/usr/bin/bash
REPO="https://github.com/Lubnysash1980/cybra-node.git"
ROOT="$HOME/CYBRA"
command -v git >/dev/null 2>&1 || pkg install -y git
command -v python3 >/dev/null 2>&1 || pkg install -y python
if [ -d "$ROOT/.git" ]; then (cd "$ROOT" && git pull --rebase); else
  [ -d "$ROOT" ] && mv "$ROOT" "$ROOT.old.$(date +%s)"
  git clone "$REPO" "$ROOT"
fi
cd "$ROOT"
chmod +x cybra cybra_mega_hardening.sh install.sh 2>/dev/null
find bin -type f -exec chmod +x {} \; 2>/dev/null
find modules -name '*.sh' -exec chmod +x {} \; 2>/dev/null
find modules -name '*.py' -exec chmod +x {} \; 2>/dev/null
find ai -name '*.sh' -exec chmod +x {} \; 2>/dev/null
grep -q 'CYBRA/bin' ~/.bashrc 2>/dev/null || echo 'export PATH="$HOME/CYBRA/bin:$PATH"' >> ~/.bashrc
export PATH="$ROOT/bin:$PATH"
[ ! -f .owner ] && { printf 'CYBRA_OWNER_%s\n' "$(date -u +%Y%m%dT%H%M%SZ)" > .owner; chmod 600 .owner; }
rm -f .*.pid .parawatch.state 2>/dev/null
echo "✓ ГОТОВО. Запусти: source ~/.bashrc && cybra_boot && cybra"
