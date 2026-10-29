#!/data/data/com.termux/files/usr/bin/bash
set -u
REMOTE="git@github.com:Lubnysash1980/cybra-node.git"
mkdir -p ~/.ssh; chmod 700 ~/.ssh
[ -f ~/.ssh/config ] && cp ~/.ssh/config ~/.ssh/config.bak.$(date +%s)
chmod 600 ~/.ssh/id_ed25519* 2>/dev/null

echo "=== 1. TEST KEYS ==="
GOOD=""
for k in id_ed25519 id_ed25519_github; do
  [ -f ~/.ssh/$k ] || continue
  out=$(timeout 8 ssh -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=accept-new -i ~/.ssh/$k -T git@github.com 2>&1 | head -1)
  echo "  $k → $out"
  echo "$out" | grep -q "successfully authenticated" && [ -z "$GOOD" ] && GOOD="$k"
done

if [ -z "$GOOD" ]; then
  echo "⚠️  Жоден ключ не пускає GitHub. Додай один з цих публічних ключів у GitHub Settings → SSH keys:"
  for k in id_ed25519 id_ed25519_github; do [ -f ~/.ssh/$k.pub ] && echo "--- $k ---" && cat ~/.ssh/$k.pub; done
  echo "Потім запусти: bash ~/CYBRA/cybra_git_ssh_setup.sh"
  exit 2
fi
echo "  ✅ working key: $GOOD"

echo "=== 2. WRITE ~/.ssh/config ==="
cat > ~/.ssh/config <<EOF
Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/$GOOD
  IdentitiesOnly yes
  StrictHostKeyChecking accept-new
EOF
chmod 600 ~/.ssh/config
echo "  done"

echo "=== 3. VERIFY ==="
timeout 8 ssh -T git@github.com 2>&1 | head -1 | sed 's/^/  /'

echo "=== 4. GIT IN ~/CYBRA ==="
cd ~/CYBRA || exit 1
if [ ! -d .git ]; then
  echo "  no .git → git init"
  git init -q
  git branch -M main 2>/dev/null
fi
git remote remove origin 2>/dev/null
git remote add origin "$REMOTE"
git remote -v | sed 's/^/  /'

echo "=== 5. FETCH (тільки читає, твої файли не чіпає) ==="
timeout 45 git fetch origin 2>&1 | tail -4 | sed 's/^/  /'
echo "  remote main: $(git log origin/main --oneline -1 2>&1 | head -1)"
echo "  local HEAD:  $(git rev-parse --short HEAD 2>&1)"
echo "  status:      $(git status -sb 2>&1 | head -1)"

echo "=== DONE ==="
echo "Далі: git -C ~/CYBRA status  →  побачиш що локально, що в remote"
