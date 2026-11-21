// CYBRA — об'єднаний конфіг (infrastructure + business)
// Запуск: pm2 start ecosystem.config.js
const CYBRA = process.env.HOME + '/CYBRA';

module.exports = {
  apps: [
    // ═══════ INFRASTRUCTURE (пристрій 1) ═══════
    { name: 'cybra-core',       script: `${CYBRA}/core/autonomous-core.js`,              max_memory_restart: '100M', autorestart: true },
    { name: 'cybra-autogit',    script: `${CYBRA}/bin/wrappers/run_autogit.sh`,          interpreter: 'bash', max_memory_restart: '65M', autorestart: true },
    { name: 'cybra-dump',       script: `${CYBRA}/bin/wrappers/run_dump.sh`,             interpreter: 'bash', max_memory_restart: '65M', autorestart: true },
    { name: 'cybra-manifest',   script: `${CYBRA}/bin/wrappers/run_manifest.sh`,         interpreter: 'bash', max_memory_restart: '65M', autorestart: true },
    { name: 'cybra-reaper',     script: `${CYBRA}/bin/wrappers/run_reaper.sh`,           interpreter: 'bash', max_memory_restart: '65M', autorestart: true },
    { name: 'cybra-stage',      script: `${CYBRA}/bin/wrappers/run_stage_analytics.sh`,  interpreter: 'bash', max_memory_restart: '65M', autorestart: true },
    { name: 'cybra-locate',     script: `${CYBRA}/modules/cybra-locate/bin/scan_daemon.sh`, interpreter: 'bash', max_memory_restart: '65M', autorestart: true },
    { name: 'cybra-sync',       script: `${CYBRA}/modules/cybra-sync/bin/sync_daemon.sh`,   interpreter: 'bash', max_memory_restart: '65M', autorestart: true },
    { name: 'redis',            script: 'redis-server',                                   interpreter: 'none', max_memory_restart: '65M', autorestart: true },

    // ═══════ BUSINESS — TAXI MODULES (пристрій 2) ═══════
    { name: 'taxi-events',      script: `${CYBRA}/bin/cybra_taxi_events.py`,              interpreter: 'python3', max_memory_restart: '65M', autorestart: true },
    { name: 'level-tracker',    script: `${CYBRA}/cybra_level_tracker.sh`,                interpreter: 'bash', max_memory_restart: '65M', autorestart: true },
    { name: 'menu-worker',      script: `${CYBRA}/parliament_menu_worker.sh`,             interpreter: 'bash', max_memory_restart: '65M', autorestart: true },
    { name: 'parliament',       script: `${CYBRA}/parliament_executor_v6.py`,             interpreter: 'python3', max_memory_restart: '80M', autorestart: true },

    // ═══════ NEURO / SYS (пристрій 2) ═══════
    { name: 'cybra-neuro-ctrl',     script: `${CYBRA}/bin/cybra_neuro_controller.py`,        interpreter: 'python3', max_memory_restart: '80M', autorestart: true },
    { name: 'cybra-evolution-ctrl', script: `${CYBRA}/bin/cybra_evolution_controller.py`,    interpreter: 'python3', max_memory_restart: '80M', autorestart: true },
    { name: 'cybra-oracle-ctrl',    script: `${CYBRA}/bin/cybra_oracle_controller.py`,       interpreter: 'python3', max_memory_restart: '65M', autorestart: true },
    { name: 'cybra-resurrection-ctrl', script: `${CYBRA}/bin/cybra_resurrection_controller.py`, interpreter: 'python3', max_memory_restart: '65M', autorestart: true },
    { name: 'cybra-orchestrator',   script: `${CYBRA}/dual-ai/orchestrator.js`,               max_memory_restart: '80M', autorestart: true },

    // ═══════ BUSINESS — API / core (пристрій 2) ═══════
    { name: 'cybra-api',        script: `${CYBRA}/api/run.sh`,                             interpreter: 'bash', max_memory_restart: '100M', autorestart: true },
    { name: 'cybra-monolith',   script: `${CYBRA}/bin/cybra-monolith.py`,                  interpreter: 'python3', max_memory_restart: '100M', autorestart: true },
    { name: 'cybra-brain',      script: `${CYBRA}/brain/brain_core.py`,                    interpreter: 'python3', max_memory_restart: '80M', autorestart: true },
    { name: 'mock-ai',          script: `${CYBRA}/bin/cybra_closed_sha_pool_bridge.py`,    interpreter: 'python3', max_memory_restart: '65M', autorestart: true },

    // ═══════ CONTROLLER (пристрій 1) ═══════
    { name: 'cybra-ctl-v2',     script: `${CYBRA}/cybra-controller-v2.sh`,                 interpreter: 'bash', max_memory_restart: '50M', autorestart: true },
  ]
};
