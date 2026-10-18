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
    { name: "cybra-node-7", script: "/data/data/com.termux/files/home/CYBRA/nodes/node_7/node_7.py", interpreter: "python3", cwd: "/data/data/com.termux/files/home/CYBRA", autorestart: true }
  ]
};
