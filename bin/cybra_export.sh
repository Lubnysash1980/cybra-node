#!/data/data/com.termux/files/usr/bin/bash
set -u
TS=$(date +%Y%m%d_%H%M)
BUNDLE="${1:-$HOME/cybra-export-$TS}"
mkdir -p "$BUNDLE"/{boot-hooks,meta}

echo "═══ CYBRA EXPORT → $BUNDLE ═══"

# MANIFEST
cat > "$BUNDLE/MANIFEST.json" << JSON
{
  "ts": "$(date -Iseconds)",
  "source_host": "$(hostname 2>/dev/null || echo unknown)",
  "android": "$(getprop ro.build.version.release 2>/dev/null || echo unknown)",
  "model": "$(getprop ro.product.model 2>/dev/null || echo unknown)",
  "stakeawtodump": "$(jq -r '.version // "?"' ~/CYBRA/modules/stakeawtodump/manifest.json 2>/dev/null)",
  "parliament": "$(jq -r '.version // "?"' ~/CYBRA/modules/parliament/manifest.json 2>/dev/null)",
  "autodopomoga": "$(jq -r '.version // "?"' ~/CYBRA/modules/autodopomoga/manifest.json 2>/dev/null)",
  "stats": "$(jq -r '.version // "?"' ~/CYBRA/modules/stats/manifest.json 2>/dev/null)"
}
JSON

# 1. CYBRA (код + dumps + state), без .git/pid/lock/logs/.backup
echo "── packing CYBRA"
tar czf "$BUNDLE/cybra.tar.gz" -C ~ \
    --exclude='CYBRA/.git' \
    --exclude='CYBRA/.backup' \
    --exclude='CYBRA/.cache/*.pid' \
    --exclude='CYBRA/.cache/*.lock' \
    --exclude='CYBRA/logs/*.log' \
    CYBRA/

# 2. logs — last 500 lines
echo "── packing logs (trimmed)"
mkdir -p "$BUNDLE/.tmp/logs"
for f in ~/CYBRA/logs/*.log; do
    [ -f "$f" ] && tail -500 "$f" > "$BUNDLE/.tmp/logs/$(basename "$f")"
done
tar czf "$BUNDLE/logs.tar.gz" -C "$BUNDLE/.tmp"
rm -rf "$BUNDLE/.tmp"

# 3. golden
echo "── packing golden"
tar czf "$BUNDLE/golden.tar.gz" -C ~ .cybra-golden/

# 4. bashrc
cp ~/.bashrc "$BUNDLE/bashrc"

# 5. crontab
crontab -l > "$BUNDLE/crontab.txt" 2>/dev/null || echo "# empty" > "$BUNDLE/crontab.txt"

# 6. boot hooks
cp -p ~/.termux/boot/*.sh "$BUNDLE/boot-hooks/" 2>/dev/null

# 7. pm2 dump
[ -f ~/.pm2/dump.pm2 ] && cp ~/.pm2/dump.pm2 "$BUNDLE/pm2-dump.pm2"

# 8. packages
{
    echo "# Install on new device:"
    echo "pkg update && pkg upgrade -y"
    echo "pkg install -y bash jq git nodejs-lts redis cronie termux-api coreutils"
    echo "npm install -g pm2"
    echo ""
    echo "# Installed here:"
    pkg list-installed 2>/dev/null | grep -E '^(bash|jq|git|nodejs|redis|cronie|termux-api|coreutils)/' || true
} > "$BUNDLE/packages.txt"

# 9. checksums
echo "── checksums"
( cd "$BUNDLE" && sha256sum MANIFEST.json cybra.tar.gz logs.tar.gz golden.tar.gz bashrc crontab.txt boot-hooks/*.sh pm2-dump.pm2 2>/dev/null ) > "$BUNDLE/checksums.txt"

# 10. restore.sh
cat > "$BUNDLE/restore.sh" << 'RESTORE'
#!/data/data/com.termux/files/usr/bin/bash
set -u
BUNDLE="$(cd "$(dirname "$0")" && pwd)"
LOG="$HOME/cybra-restore-$(date +%Y%m%d_%H%M).log"
log(){ echo "[$(date '+%F %T')] $*" | tee -a "$LOG"; }

log "═══ CYBRA RESTORE ═══"
log "bundle: $BUNDLE"
log "log:    $LOG"

# ─── 0. checksums ───
if [ -f "$BUNDLE/checksums.txt" ]; then
    BAD=$( cd "$BUNDLE" && sha256sum -c checksums.txt 2>&1 | grep -v ': OK$' )
    if [ -n "$BAD" ]; then log "❌ checksums: $BAD"; exit 1; fi
    log "✅ checksums OK"
fi

# ─── 1. deps check ───
MISS=""
for p in jq git node pm2 redis-cli crond; do
    command -v "$p" >/dev/null 2>&1 || MISS="$MISS $p"
done
[ -n "$MISS" ] && {
    log "⚠ missing:$MISS"
    log "  pkg install -y bash jq git nodejs-lts redis cronie termux-api"
    log "  npm install -g pm2"
}

# ─── 2. backup existing ───
[ -d "$HOME/CYBRA" ] && {
    BAK="$HOME/CYBRA.pre-restore.$(date +%s)"
    log "── existing CYBRA → $BAK"
    mv "$HOME/CYBRA" "$BAK"
}

# ─── 3. extract CYBRA ───
log "── extracting cybra"
tar xzf "$BUNDLE/cybra.tar.gz" -C "$HOME" || { log "❌ extract failed"; exit 1; }
find "$HOME/CYBRA" -name '*.sh' -exec chmod +x {} \; 2>/dev/null

# ─── 4. logs ───
[ -f "$BUNDLE/logs.tar.gz" ] && {
    log "── merging logs"
    tar xzf "$BUNDLE/logs.tar.gz" -C "$HOME/CYBRA/" 2>/dev/null || true
}

# ─── 5. golden ───
[ -d "$HOME/.cybra-golden" ] && mv "$HOME/.cybra-golden" "$HOME/.cybra-golden.pre-restore.$(date +%s)"
[ -f "$BUNDLE/golden.tar.gz" ] && {
    log "── restoring golden"
    tar xzf "$BUNDLE/golden.tar.gz" -C "$HOME"
}

# ─── 6. bashrc merge ───
[ -f "$BUNDLE/bashrc" ] && {
    [ -f "$HOME/.bashrc" ] && cp "$HOME/.bashrc" "$HOME/.bashrc.pre-restore.$(date +%s)"
    if ! grep -q '# ── @cybra' "$HOME/.bashrc" 2>/dev/null; then
        log "── adding @cybra block to .bashrc"
        echo "" >> "$HOME/.bashrc"
        echo "# ── merged by cybra-restore ──" >> "$HOME/.bashrc"
        sed -n '/# ── @cybra v2 ──/,$p' "$BUNDLE/bashrc" >> "$HOME/.bashrc"
    fi
}

# ─── 7. boot hooks ───
[ -d "$BUNDLE/boot-hooks" ] && {
    mkdir -p "$HOME/.termux/boot"
    for f in "$BUNDLE/boot-hooks"/*.sh; do
        [ -f "$f" ] || continue
        cp "$f" "$HOME/.termux/boot/"
        chmod +x "$HOME/.termux/boot/$(basename "$f")"
    done
    log "── boot hooks installed (need Termux:Boot app)"
}

# ─── 8. crontab ───
[ -f "$BUNDLE/crontab.txt" ] && {
    crontab -l 2>/dev/null > "$HOME/crontab.pre-restore.$(date +%s)" 2>/dev/null || true
    crontab "$BUNDLE/crontab.txt" 2>/dev/null && log "── crontab installed" || log "⚠ crontab failed"
}

# ─── 9. pm2 ───
[ -f "$BUNDLE/pm2-dump.pm2" ] && {
    mkdir -p "$HOME/.pm2"
    cp "$BUNDLE/pm2-dump.pm2" "$HOME/.pm2/dump.pm2"
    log "── pm2 resurrect"
    pm2 resurrect 2>&1 | tail -3
    pm2 save --force >/dev/null 2>&1
}

# ─── 10. daemons ───
log "── starting daemons"
[ -x "$HOME/CYBRA/bin/cybra_bg_dump_ctl.sh" ] && "$HOME/CYBRA/bin/cybra_bg_dump_ctl.sh" start 2>&1
[ -x "$HOME/CYBRA/bin/cybra_autowatch_ctl.sh" ] && "$HOME/CYBRA/bin/cybra_autowatch_ctl.sh" start 2>&1
sleep 2
[ -x "$HOME/CYBRA/modules/autodopomoga/bin/ctl.sh" ] && "$HOME/CYBRA/modules/autodopomoga/bin/ctl.sh" start 2>&1
[ -x "$HOME/CYBRA/modules/parliament/bin/parliament_ctl.sh" ] && "$HOME/CYBRA/modules/parliament/bin/parliament_ctl.sh" start 2>&1
[ -x "$HOME/CYBRA/modules/stats/bin/ctl.sh" ] && "$HOME/CYBRA/modules/stats/bin/ctl.sh" start 2>&1

# ─── 11. verify ───
sleep 5
log "── verify"
bash -c 'source ~/.bashrc 2>/dev/null; @cybra' 2>&1 | tee -a "$LOG"

log "═══ RESTORE DONE ═══"
log "⚠ manual:"
log "  1. Termux:Boot app (F-Droid)"
log "  2. Battery → Unrestricted"
log "  3. crontab -l (verify)"
log "  4. source ~/.bashrc"
RESTORE
chmod +x "$BUNDLE/restore.sh"

echo ""
echo "═══ EXPORT DONE ═══"
echo "bundle: $BUNDLE"
du -sh "$BUNDLE"
echo ""
ls -la "$BUNDLE/"
echo ""
echo "── transfer ──"
echo "  scp:    scp -r $BUNDLE user@host:~/"
echo "  adb:    adb push $BUNDLE /sdcard/"
echo "  cloud:  tar czf /sdcard/cybra-mig.tgz -C $HOME $(basename $BUNDLE)"
