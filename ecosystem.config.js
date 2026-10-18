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
