#!/data/data/com.termux/files/usr/bin/bash
# cybra_restore_golden.sh — відкат bin/ + modules/ зі "золотої" копії.
# Використання: cybra_restore_golden.sh [--force]
set -u
GOLD="$HOME/.cybra-golden"
CYBRA="$HOME/CYBRA"
FORCE="${1:-}"

[ -f "$GOLD/bin.tar" ] && [ -f "$GOLD/modules.tar" ] || {
  echo "✗ no golden backup in $GOLD"; exit 1
}

# safety: не перетирати живий bin/ без --force
if [ -d "$CYBRA/bin" ] && [ "$FORCE" != "--force" ]; then
  N=$(find "$CYBRA/bin" -maxdepth 1 -name 'cybra_*.sh' 2>/dev/null | wc -l)
  if [ "$N" -ge 6 ]; then
    echo "✗ bin/ виглядає живим ($N скриптів). Використай --force щоб перетерти"
    echo "  або: cybra_restore_golden.sh --force"
    exit 1
  fi
fi

# бекап поточного (може битого) стану перед відкатом
TS=$(date +%s)
[ -d "$CYBRA/bin" ]     && tar cf "$GOLD/bin.broken.$TS.tar"     -C "$CYBRA" bin     2>/dev/null
[ -d "$CYBRA/modules" ] && tar cf "$GOLD/modules.broken.$TS.tar" -C "$CYBRA" modules 2>/dev/null

# зупинити що біжить, щоб не заважало
[ -x "$CYBRA/bin/cybra_autowatch_ctl.sh" ] && "$CYBRA/bin/cybra_autowatch_ctl.sh" stop 2>/dev/null
[ -x "$CYBRA/bin/cybra_bg_dump_ctl.sh" ]   && "$CYBRA/bin/cybra_bg_dump_ctl.sh"   stop 2>/dev/null

# розпакувати golden
tar xf "$GOLD/bin.tar"     -C "$CYBRA"
tar xf "$GOLD/modules.tar" -C "$CYBRA"

# відновити біти
chmod +x "$CYBRA/bin/"*.sh "$CYBRA/bin/wrappers/"*.sh \
         "$CYBRA/modules/stakeawtodump/bin/"*.sh 2>/dev/null

# перевірка цілісності
if [ -f "$GOLD/checksums.txt" ]; then
  ( cd "$CYBRA" && sha256sum -c "$GOLD/checksums.txt" 2>/dev/null \
      | grep -v ': OK$' || true )
fi

# підняти
[ -x "$CYBRA/bin/cybra_autowatch_ctl.sh" ] && "$CYBRA/bin/cybra_autowatch_ctl.sh" start
sleep 3
echo "✓ restored from golden"

# короткий статус
[ -x "$CYBRA/modules/stakeawtodump/bin/status.sh" ] && \
  "$CYBRA/modules/stakeawtodump/bin/status.sh" short
