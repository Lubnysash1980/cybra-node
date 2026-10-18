#!/data/data/com.termux/files/usr/bin/bash
CYBRA="$HOME/CYBRA"

echo "═══ 1. СТВОРЕННЯ ПОВНОГО ecosystem.config.js (16 ПРОЦЕСІВ) ═══"
cat > "$CYBRA/ecosystem.config.js" <<'ECOEOF'
module.exports = {
  apps: [
    { name: "cybra-autonode-main", script: "/data/data/com.termux/files/home/CYBRA/bin/run_node.js", args: ["/data/data/com.termux/files/home/CYBRA/bin/cybra_autonode_main"], interpreter: "node", cwd: "/data/data/com.termux/files/home/CYBRA", autorestart: true },
    { name: "cybra-autonode-cybra", script: "/data/data/com.termux/files/home/CYBRA/bin/run_node.js", args: ["/data/data/com.termux/files/home/CYBRA/bin/cybra_autonode_cybra"], interpreter: "node", cwd: "/data/data/com.termux/files/home/CYBRA", autorestart: true },
    { name: "cybra-parliament-worker", script: "/data/data/com.termux/files/home/CYBRA/parliament_auto_worker.sh", interpreter: "bash", cwd: "/data/data/com.termux/files/home/CYBRA", autorestart: true },
    { name: "cybra-parliament-priority", script: "/data/data/com.termux/files/home/CYBRA/parliament_core/priority_manager.py", args: ["daemon"], interpreter: "python3", cwd: "/data/data/com.termux/files/home/CYBRA", autorestart: true },
    { name: "cybra-selfgen-daemon", script: "/data/data/com.termux/files/home/CYBRA/selfgen/selfgen_core.py", args: ["daemon"], interpreter: "python3", cwd: "/data/data/com.termux/files/home/CYBRA", autorestart: true },
    { name: "cybra-brain-daemon", script: "/data/data/com.termux/files/home/CYBRA/brain/brain_core.py", args: ["daemon"], interpreter: "python3", cwd: "/data/data/com.termux/files/home/CYBRA", autorestart: true },
    { name: "cybra-evo-daemon", script: "/data/data/com.termux/files/home/CYBRA/evo/evo_core.py", args: ["daemon"], interpreter: "python3", cwd: "/data/data/com.termux/files/home/CYBRA", autorestart: true },
    { name: "cybra-node-1", script: "/data/data/com.termux/files/home/CYBRA/nodes/node_1/node_1.py", interpreter: "python3", cwd: "/data/data/com.termux/files/home/CYBRA", autorestart: true },
    { name: "cybra-node-2", script: "/data/data/com.termux/files/home/CYBRA/nodes/node_2/node_2.py", interpreter: "python3", cwd: "/data/data/com.termux/files/home/CYBRA", autorestart: true },
    { name: "cybra-node-3", script: "/data/data/com.termux/files/home/CYBRA/nodes/node_3/node_3.py", interpreter: "python3", cwd: "/data/data/com.termux/files/home/CYBRA", autorestart: true },
    { name: "cybra-node-4", script: "/data/data/com.termux/files/home/CYBRA/nodes/node_4/node_4.py", interpreter: "python3", cwd: "/data/data/com.termux/files/home/CYBRA", autorestart: true },
    { name: "cybra-node-5", script: "/data/data/com.termux/files/home/CYBRA/nodes/node_5/node_5.py", interpreter: "python3", cwd: "/data/data/com.termux/files/home/CYBRA", autorestart: true },
    { name: "cybra-node-6", script: "/data/data/com.termux/files/home/CYBRA/nodes/node_6/node_6.py", interpreter: "python3", cwd: "/data/data/com.termux/files/home/CYBRA", autorestart: true },
    { name: "cybra-node-7", script: "/data/data/com.termux/files/home/CYBRA/nodes/node_7/node_7.py", interpreter: "python3", cwd: "/data/data/com.termux/files/home/CYBRA", autorestart: true },
    { name: "cybra-lifecycle", script: "/data/data/com.termux/files/home/CYBRA/lifecycle/lifecycle_manager.py", args: ["daemon"], interpreter: "python3", cwd: "/data/data/com.termux/files/home/CYBRA", autorestart: true },
    { name: "cybra-autoresolver", script: "/data/data/com.termux/files/home/CYBRA/lifecycle/autoresolver.py", args: ["daemon"], interpreter: "python3", cwd: "/data/data/com.termux/files/home/CYBRA", autorestart: true }
  ]
};
ECOEOF
echo "  [✓] ecosystem.config.js створено (16 процесів)"

echo ""
echo "═══ 2. ПЕРЕЗАПУСК PM2 ═══"
pm2 delete all 2>/dev/null
pm2 start "$CYBRA/ecosystem.config.js"
pm2 save 2>/dev/null
sleep 3
echo "  [✓] PM2 перезапущено"

echo ""
echo "═══ 3. КОМІТ 83 ФАЙЛІВ У GIT ═══"
cd "$CYBRA" || exit 1
git add -A
git commit -m "feat: full ecosystem with lifecycle + autoresolver (16 processes)" -q 2>/dev/null
git push origin main -q 2>/dev/null
echo "  [✓] Закомічено і запушено"

echo ""
echo "═══ 4. ФІНАЛЬНА ПЕРЕВІРКА ═══"
sleep 2
pm2 status
echo ""
python3 "$CYBRA/check_100_percent.py"
