module.exports = {
  apps: [
    // 1. Головна нода (яку ми щойно створили)
    {
      name: "cybra-node-1",
      script: "/data/data/com.termux/files/home/CYBRA/nodes/node_1/node_1.py",
      interpreter: "python3",
      cwd: "/data/data/com.termux/files/home/CYBRA",
      autorestart: true,
      max_memory_restart: "150M"
    },
    // 2. Парламент (якщо є на цьому пристрої)
    {
      name: "cybra-parliament-priority",
      script: "/data/data/com.termux/files/home/CYBRA/parliament_core/priority_manager.py",
      args: ["daemon"],
      interpreter: "python3",
      cwd: "/data/data/com.termux/files/home/CYBRA",
      autorestart: true
    },
    // 3. EVO (еволюція)
    {
      name: "cybra-evo-daemon",
      script: "/data/data/com.termux/files/home/CYBRA/evo/evo_core.py",
      args: ["daemon"],
      interpreter: "python3",
      cwd: "/data/data/com.termux/files/home/CYBRA",
      autorestart: true
    },
    // 4. Brain (мозок)
    {
      name: "cybra-brain-daemon",
      script: "/data/data/com.termux/files/home/CYBRA/brain/brain_core.py",
      args: ["daemon"],
      interpreter: "python3",
      cwd: "/data/data/com.termux/files/home/CYBRA",
      autorestart: true
    },
    // 5. Selfgen (генератор)
    {
      name: "cybra-selfgen-daemon",
      script: "/data/data/com.termux/files/home/CYBRA/selfgen/selfgen_core.py",
      args: ["daemon"],
      interpreter: "python3",
      cwd: "/data/data/com.termux/files/home/CYBRA",
      autorestart: true
    },
    // 6. Autonode (автономний вузол)
    {
      name: "cybra-autonode-main",
      script: "/data/data/com.termux/files/home/CYBRA/bin/cybra_autonode_main.js",
      interpreter: "node",
      cwd: "/data/data/com.termux/files/home/CYBRA",
      autorestart: true
    }
  ]
};
