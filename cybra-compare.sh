#!/data/data/com.termux/files/usr/bin/bash
cd "$HOME/CYBRA" || exit 1
echo "╔════════════════════════════════════════════╗"
echo "║  ЩО Є НА ЦЬОМУ ПРИСТРОЇ                    ║"
echo "╚════════════════════════════════════════════╝"
echo ""
echo "── Модулі (папки) ──"
ls -d modules/*/ 2>/dev/null | xargs -n1 basename 2>/dev/null || echo "  (немає)"
echo ""
echo "── parliament ──"
if [ -d modules/parliament ]; then
    echo "  ✅ папка є"
    echo "  bin/:     $(ls modules/parliament/bin 2>/dev/null | wc -l | tr -d ' ') файлів"
    echo "  state/:   $(ls modules/parliament/state 2>/dev/null | wc -l | tr -d ' ') файлів"
    echo "  proposals: $(ls modules/parliament/state/proposals 2>/dev/null | wc -l | tr -d ' ') файлів"
    [ -f modules/parliament/manifest.json ] && echo "  manifest: ✅" || echo "  manifest: ❌"
else
    echo "  ❌ папки немає взагалі"
fi
echo ""
echo "── Інші модулі — детально ──"
for m in modules/*/; do
  [ -d "$m" ] || continue
  n=$(basename "$m")
  [ "$n" = "parliament" ] && continue
  echo "  ● $n: bin=$(ls "$m/bin" 2>/dev/null | wc -l | tr -d ' ') state=$(ls "$m/state" 2>/dev/null | wc -l | tr -d ' ')"
done
echo ""
echo "── contracts.json ──"
[ -f modules/autodopomoga/contracts.json ] && \
  echo "  ✅ $(jq 'keys|length' modules/autodopomoga/contracts.json 2>/dev/null) контрактів" || \
  echo "  ❌ немає"
echo ""
echo "── PM2 ──"
pm2 jlist 2>/dev/null | jq -r '.[] | "  \(.name) [\(.pm2_env.status)]"' 2>/dev/null || echo "  (порожній)"
echo ""
echo "── Git ──"
git log --oneline -3 2>/dev/null
echo "  origin: $(git remote get-url origin 2>/dev/null || echo 'немає')"
echo ""
echo "── Розмір CYBRA ──"
du -sh ~/CYBRA 2>/dev/null
echo "  (без node_modules: $(du -sh --exclude=node_modules ~/CYBRA 2>/dev/null | cut -f1))"
echo ""
echo "── Чи є щось у dumps/ ──"
ls dumps/ 2>/dev/null | head -5
