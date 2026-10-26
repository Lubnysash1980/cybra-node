#!/data/data/com.termux/files/usr/bin/bash
# BACKUP — git bundle + tar.gz working tree → SD card + external flash
# Тільки якщо state_100 = 100%. Idempotent.
set -uo pipefail
CYBRA="$HOME/CYBRA"; cd "$CYBRA" || exit 1
TS=$(date +%Y%m%d_%H%M%S)

echo "═══ CYBRA BACKUP EXTERNAL ($TS) ═══"

# ─── 1. VERIFY 100% STATE ───
echo ""
echo "── 1. verify 100% state ──"
PCT=$(python3 -c "import json;print(json.load(open('state/snapshots/_master.json'))['pct'])" 2>/dev/null || echo 0)
if [ "$PCT" != "100.0" ] && [ "$PCT" != "100" ]; then
  echo "  ❌ state_100 = $PCT% — треба 100%"
  echo "  спершу: bash bin/cybra_state_100.sh"
  exit 1
fi
echo "  ✅ state = $PCT%"

# ─── 2. STORAGE PERMISSION ───
echo ""
echo "── 2. storage permission ──"
if [ ! -d /sdcard ] || [ ! -w /sdcard ] 2>/dev/null; then
  echo "  ⚠️  /sdcard не writable — виклич termux-setup-storage"
  echo "  (якщо вже є, ігноруй)"
fi

# ─── 3. FIND DESTINATIONS ───
echo ""
echo "── 3. find destinations ──"
DESTINATIONS=()
# internal shared storage
for d in /sdcard /storage/emulated/0; do
  [ -d "$d" ] && [ -w "$d" ] 2>/dev/null && DESTINATIONS+=("$d/CYBRA_BACKUP") && break
done
# external SD / USB (не emulated)
for d in /storage/*; do
  case "$d" in
    */emulated*|*/self) continue ;;
  esac
  [ -d "$d" ] && [ -w "$d" ] 2>/dev/null && DESTINATIONS+=("$d/CYBRA_BACKUP")
done

if [ ${#DESTINATIONS[@]} -eq 0 ]; then
  echo "  ❌ жодного writable storage"
  echo "     termux-setup-storage"
  exit 1
fi
for d in "${DESTINATIONS[@]}"; do echo "  ✅ $d"; done

# ─── 4. SPACE CHECK (need ~500MB) ───
echo ""
echo "── 4. space check ──"
NEED_MB=500
for d in "${DESTINATIONS[@]}"; do
  PARENT=$(dirname "$d")
  FREE=$(df -m "$PARENT" 2>/dev/null | awk 'NR==2{print $4}')
  if [ -z "$FREE" ] || [ "$FREE" -lt "$NEED_MB" ]; then
    echo "  ⚠️  $PARENT: $FREE MB < $NEED_MB — skip"
    DESTINATIONS=("${DESTINATIONS[@]/$d}")
  else
    echo "  ✅ $PARENT: $FREE MB free"
  fi
done
DESTINATIONS=($(printf '%s\n' "${DESTINATIONS[@]}" | grep -v '^$'))

# ─── 5. GIT BUNDLE (повна історія, 1 файл) ───
echo ""
echo "── 5. git bundle ──"
BUNDLE="$HOME/cybra_$TS.bundle"
git bundle create "$BUNDLE" --all 2>&1 | tail -2
BUNDLE_SHA=$(sha256sum "$BUNDLE" | awk '{print $1}')
BUNDLE_SIZE=$(du -h "$BUNDLE" | cut -f1)
echo "  ✅ $BUNDLE ($BUNDLE_SIZE)"
echo "     sha256: ${BUNDLE_SHA:0:16}..."

# ─── 6. TAR.GZ WORKING TREE (без runtime, без backups) ───
echo ""
echo "── 6. tar.gz working tree ──"
TARBALL="$HOME/cybra_working_$TS.tar.gz"
tar -czf "$TARBALL" \
  --exclude='.git/objects/pack/pack-*' \
  --exclude='node_modules' \
  --exclude='state/module_backups' \
  --exclude='state/autobuild_backup_*' \
  --exclude='state/evo_backups' \
  --exclude='state/evo_premium_backups' \
  --exclude='state/evo_upgrade_backups' \
  --exclude='state/hidl_backups' \
  --exclude='state/tag_backup' \
  --exclude='state/named_backup' \
  --exclude='state/backup' \
  --exclude='logs' \
  --exclude='snapshots' \
  --exclude='sandbox' \
  --exclude='.binmix/snapshots' \
  --exclude='*.pyc' \
  --exclude='*.tar.gz' \
  -C "$HOME" "CYBRA" 2>/dev/null
TAR_SHA=$(sha256sum "$TARBALL" | awk '{print $1}')
TAR_SIZE=$(du -h "$TARBALL" | cut -f1)
echo "  ✅ $TARBALL ($TAR_SIZE)"
echo "     sha256: ${TAR_SHA:0:16}..."

# ─── 7. CHECKSUMS FILE ───
echo ""
echo "── 7. checksums ──"
CHECK="$HOME/cybra_${TS}_SHA256SUMS.txt"
cat > "$CHECK" <<CHK
# CYBRA backup $TS
# state_100 = $PCT%
# git HEAD = $(git rev-parse HEAD)
# git tag  = $(git describe --tags --always 2>/dev/null || echo none)
$BUNDLE_SHA  $(basename "$BUNDLE")
$TAR_SHA     $(basename "$TARBALL")
CHK
echo "  ✅ $CHECK"

# ─── 8. COPY TO EACH DESTINATION ───
echo ""
echo "── 8. copy to destinations ──"
COPIED=0
for d in "${DESTINATIONS[@]}"; do
  echo ""
  echo "  → $d"
  mkdir -p "$d" 2>/dev/null || { echo "    ❌ mkdir fail"; continue; }

  cp "$BUNDLE"  "$d/" && echo "    ✅ $(basename "$BUNDLE")"
  cp "$TARBALL" "$d/" && echo "    ✅ $(basename "$TARBALL")"
  cp "$CHECK"   "$d/" && echo "    ✅ $(basename "$CHECK")"

  # verify
  cd "$d"
  OK=1
  echo "$BUNDLE_SHA  $(basename "$BUNDLE")"  | sha256sum -c - >/dev/null 2>&1 || OK=0
  echo "$TAR_SHA     $(basename "$TARBALL")" | sha256sum -c - >/dev/null 2>&1 || OK=0
  cd "$CYBRA"
  if [ "$OK" -eq 1 ]; then
    echo "    ✅ sha256 verify OK"
    COPIED=$((COPIED+1))
  else
    echo "    ❌ sha256 MISMATCH"
  fi
done

# ─── 9. KEEP ONLY 3 LATEST PER DESTINATION ───
echo ""
echo "── 9. rotate (keep 3 latest) ──"
for d in "${DESTINATIONS[@]}"; do
  for pat in "cybra_*.bundle" "cybra_working_*.tar.gz"; do
    ls -t "$d"/$pat 2>/dev/null | tail -n +4 | while read old; do
      rm -f "$old" && echo "  🗑 $d/$(basename "$old")"
    done
  done
done

# ─── 10. SUMMARY ───
echo ""
echo "═══ BACKUP DONE ═══"
echo "  state:      $PCT%"
echo "  git HEAD:   $(git rev-parse --short HEAD)"
echo "  bundle:     $BUNDLE_SIZE  sha256=${BUNDLE_SHA:0:16}"
echo "  working:    $TAR_SIZE     sha256=${TAR_SHA:0:16}"
echo "  copied to:  $COPIED/${#DESTINATIONS[@]} destinations"
for d in "${DESTINATIONS[@]}"; do echo "    $d"; done
echo ""
echo "  restore (на іншому пристрої):"
echo "    git clone <bundle> ~/CYBRA        # або:"
echo "    mkdir ~/CYBRA && cd ~/CYBRA && git init && git pull /path/to/bundle"
echo "    або: tar -xzf $(basename "$TARBALL") -C \$HOME"
