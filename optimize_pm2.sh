#!/data/data/com.termux/files/usr/bin/bash
CYBRA="$HOME/CYBRA"

echo "═══ 1. ПОТОЧНИЙ СТАТУС PM2 ═══"
pm2 status

echo ""
echo "═══ 2. СТВОРЕННЯ ОПТИМІЗОВАНОГО ecosystem.config.js ═══"
# Залишаємо тільки 8 найважливіших процесів (без 7 нод, щоб не жерти RAM)
cat > "$CYBRA/ecosystem.config.js" <<'ECOEOF'
module.exports = {
  apps: [
    { name: "cybra-autonode-main", script: "/data/data/com.termux/files/home/CYBRA/bin/run_node.js", args: ["/data/data/com.termux/files/home/CYBRA/bin/cybra_autonode_main"], interpreter: "node", cwd: "/data/data/com.termux/files/home/CYBRA", autorestart: true, max_memory_restart: "150M" },
    { name: "cybra-autonode-cybra", script: "/data/data/com.termux/files/home/CYBRA/bin/run_node.js", args: ["/data/data/com.termux/files/home/CYBRA/bin/cybra_autonode_cybra"], interpreter: "node", cwd: "/data/data/com.termux/files/home/CYBRA", autorestart: true, max_memory_restart: "150M" },
    { name: "cybra-parliament-worker", script: "/data/data/com.termux/files/home/CYBRA/parliament_auto_worker.sh", interpreter: "bash", cwd: "/data/data/com.termux/files/home/CYBRA", autorestart: true, max_memory_restart: "100M" },
    { name: "cybra-parliament-priority", script: "/data/data/com.termux/files/home/CYBRA/parliament_core/priority_manager.py", args: ["daemon"], interpreter: "python3", cwd: "/data/data/com.termux/files/home/CYBRA", autorestart: true, max_memory_restart: "100M" },
    { name: "cybra-selfgen-daemon", script: "/data/data/com.termux/files/home/CYBRA/selfgen/selfgen_core.py", args: ["daemon"], interpreter: "python3", cwd: "/data/data/com.termux/files/home/CYBRA", autorestart: true, max_memory_restart: "100M" },
    { name: "cybra-brain-daemon", script: "/data/data/com.termux/files/home/CYBRA/brain/brain_core.py", args: ["daemon"], interpreter: "python3", cwd: "/data/data/com.termux/files/home/CYBRA", autorestart: true, max_memory_restart: "100M" },
    { name: "cybra-evo-daemon", script: "/data/data/com.termux/files/home/CYBRA/evo/evo_core.py", args: ["daemon"], interpreter: "python3", cwd: "/data/data/com.termux/files/home/CYBRA", autorestart: true, max_memory_restart: "100M" },
    { name: "cybra-lifecycle", script: "/data/data/com.termux/files/home/CYBRA/lifecycle/lifecycle_manager.py", args: ["daemon"], interpreter: "python3", cwd: "/data/data/com.termux/files/home/CYBRA", autorestart: true, max_memory_restart: "100M" },
    { name: "cybra-autoresolver", script: "/data/data/com.termux/files/home/CYBRA/lifecycle/autoresolver.py", args: ["daemon"], interpreter: "python3", cwd: "/data/data/com.termux/files/home/CYBRA", autorestart: true, max_memory_restart: "100M" }
  ]
};
ECOEOF
echo "  [✓] ecosystem.config.js оптимізовано (9 процесів, без 7 нод)"

echo ""
echo "═══ 3. ПЕРЕЗАПУСК PM2 ═══"
pm2 delete all 2>/dev/null
pm2 start "$CYBRA/ecosystem.config.js"
pm2 save 2>/dev/null
sleep 3
echo "  [✓] PM2 перезапущено"

echo ""
echo "═══ 4. КОМІТ У GIT ═══"
cd "$CYBRA" || exit 1
git add -A
git commit -m "opt: reduce to 9 processes (no 7 nodes) for RAM" -q 2>/dev/null
git push origin main -q 2>/dev/null
echo "  [✓] Закомічено"

echo ""
echo "═══ 5. ПЕРЕВІРКА 100% ═══"
python3 "$CYBRA/check_100_percent.py"
