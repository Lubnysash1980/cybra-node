#!/data/data/com.termux/files/usr/bin/bash
cd "$HOME/CYBRA" || exit 1

echo "╔══════════════════════════════════════════╗"
echo "║  SYS + NEURO — EXTRACT                   ║"
echo "╚══════════════════════════════════════════╝"
echo ""

for f in \
  bin/cybra_neuro_controller.py \
  bin/cybra_evolution_controller.py \
  bin/cybra_resurrection_controller.py \
  bin/cybra_oracle_controller.py \
  bin/cybra_autorestore.sh \
  bin/cybra_autowatch.sh \
  bin/cybra_autowatch_ctl.sh \
  bin/cybra_bg_dump.sh \
  bin/cybra_bg_dump_ctl.sh \
  bin/cybra_start.sh \
  bin/cybra_binmix \
  controllers/module-controller.sh \
  controllers/node-controller.sh \
  dual-ai/orchestrator.js \
  node_cybra/bin/cybra_ai_bar.sh ; do
    if [ -f "$f" ]; then
      echo "══════════════════════════════════════════"
      echo "FILE: $f  ($(wc -l < "$f") рядків, $(du -h "$f"|cut -f1))"
      echo "══════════════════════════════════════════"
      head -80 "$f"
      echo ""
      echo "── ... (кінець перших 80 рядків) ──"
      echo ""
    else
      echo "❌ ВІДСУТНІЙ: $f"
      echo ""
    fi
done

echo "══════════════════════════════════════════"
echo "Структура node_cybra/"
echo "══════════════════════════════════════════"
find node_cybra -maxdepth 3 -type f 2>/dev/null | head -20

echo ""
echo "══════════════════════════════════════════"
echo "Структура dual-ai/"
echo "══════════════════════════════════════════"
find dual-ai -maxdepth 3 -type f 2>/dev/null | head -20

echo ""
echo "══════════════════════════════════════════"
echo "Структура controllers/"
echo "══════════════════════════════════════════"
ls -la controllers/ 2>/dev/null

echo ""
echo "══════════════════════════════════════════"
echo "PM2 — які з контролерів запущені?"
echo "══════════════════════════════════════════"
pm2 jlist 2>/dev/null | jq -r '.[] | "\(.name) | \(.pm2_env.status) | \(.pm2_env.pm_exec_path // "null")"' 2>/dev/null
