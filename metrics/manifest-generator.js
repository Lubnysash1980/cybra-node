#!/usr/bin/env node

'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');
const http = require('http');
const https = require('https');
const { execFile } = require('child_process');

const HOME = process.env.HOME;
const ROOT = path.join(HOME, 'CYBRA');
const STATE_DIR = path.join(ROOT, 'state');

const MANIFEST_FILE = path.join(STATE_DIR, 'manifest.json');
const STAGE_FILE = path.join(STATE_DIR, 'stage.json');

const WATCHDOG_STATE = path.join(
    ROOT,
    'openid',
    'state',
    'health-check.state'
);

const DEFAULTS = {
    intervalMs: 15000,
    healthUrl: 'http://127.0.0.1:8787/health',
    healthTimeoutMs: 5000,
    ramYellowPct: 20,
    ramRedPct: 10,
    diskYellowMb: 1024,
    diskRedMb: 256,
    logsYellowMb: 100,
    logsRedMb: 300,
    queueYellow: 50,
    queueRed: 200
};

function envInt(name, fallback, minimum = 0) {
    const value = Number.parseInt(process.env[name] || '', 10);

    if (!Number.isFinite(value) || value < minimum) {
        return fallback;
    }

    return value;
}

const CONFIG = {
    intervalMs:
        envInt('CYBRA_METRICS_INTERVAL', 15, 1) * 1000,

    healthUrl:
        process.env.HEALTH_URL ||
        DEFAULTS.healthUrl,

    healthTimeoutMs:
        envInt(
            'HEALTH_CURL_TIMEOUT',
            DEFAULTS.healthTimeoutMs / 1000,
            1
        ) * 1000,

    ramYellowPct:
        envInt(
            'CYBRA_RAM_YELLOW_PCT',
            DEFAULTS.ramYellowPct,
            0
        ),

    ramRedPct:
        envInt(
            'CYBRA_RAM_RED_PCT',
            DEFAULTS.ramRedPct,
            0
        ),

    diskYellowMb:
        envInt(
            'CYBRA_DISK_YELLOW_MB',
            DEFAULTS.diskYellowMb,
            0
        ),

    diskRedMb:
        envInt(
            'CYBRA_DISK_RED_MB',
            DEFAULTS.diskRedMb,
            0
        ),

    logsYellowMb:
        envInt(
            'CYBRA_LOGS_YELLOW_MB',
            DEFAULTS.logsYellowMb,
            0
        ),

    logsRedMb:
        envInt(
            'CYBRA_LOGS_RED_MB',
            DEFAULTS.logsRedMb,
            0
        ),

    queueYellow:
        envInt(
            'CYBRA_QUEUE_YELLOW',
            DEFAULTS.queueYellow,
            0
        ),

    queueRed:
        envInt(
            'CYBRA_QUEUE_RED',
            DEFAULTS.queueRed,
            0
        )
};

const REQUIRED_PM2 = (
    process.env.CYBRA_REQUIRED_PM2 ||
    'cybra-monolith,cybra-openid'
)
    .split(',')
    .map(value => value.trim())
    .filter(Boolean);

let running = false;
let shuttingDown = false;

function timestamp() {
    return new Date().toISOString();
}

function log(level, message) {
    console.log(`${timestamp()} [${level}] ${message}`);
}

function round(value, digits = 1) {
    const factor = 10 ** digits;
    return Math.round(value * factor) / factor;
}

function fileExists(file) {
    try {
        return fs.statSync(file).isFile();
    } catch {
        return false;
    }
}

function safeStat(file) {
    try {
        return fs.statSync(file);
    } catch {
        return null;
    }
}

function atomicWriteJSON(file, value) {
    fs.mkdirSync(path.dirname(file), {
        recursive: true,
        mode: 0o700
    });

    const temporary = `${file}.tmp.${process.pid}`;

    fs.writeFileSync(
        temporary,
        `${JSON.stringify(value, null, 2)}\n`,
        {
            encoding: 'utf8',
            mode: 0o600
        }
    );

    fs.renameSync(temporary, file);
}

function execFileAsync(command, args = [], options = {}) {
    return new Promise((resolve, reject) => {
        execFile(
            command,
            args,
            {
                timeout: options.timeout || 10000,
                maxBuffer: options.maxBuffer || 8 * 1024 * 1024,
                encoding: 'utf8',
                env: process.env
            },
            (error, stdout, stderr) => {
                if (error) {
                    error.stdout = stdout;
                    error.stderr = stderr;
                    reject(error);
                    return;
                }

                resolve({
                    stdout: stdout || '',
                    stderr: stderr || ''
                });
            }
        );
    });
}

async function commandExists(command) {
    try {
        await execFileAsync(
            process.env.SHELL || 'sh',
            ['-lc', `command -v ${command}`],
            { timeout: 3000 }
        );

        return true;
    } catch {
        return false;
    }
}

async function loadDotEnv() {
    const file = path.join(ROOT, 'openid', '.env');

    if (!fileExists(file)) {
        return;
    }

    const text = fs.readFileSync(file, 'utf8');

    for (const originalLine of text.split(/\r?\n/)) {
        const line = originalLine.trim();

        if (
            !line ||
            line.startsWith('#') ||
            !line.includes('=')
        ) {
            continue;
        }

        const separator = line.indexOf('=');
        const key = line.slice(0, separator).trim();

        let value = line.slice(separator + 1).trim();

        if (
            (value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'"))
        ) {
            value = value.slice(1, -1);
        }

        if (
            /^[A-Za-z_][A-Za-z0-9_]*$/.test(key) &&
            process.env[key] === undefined
        ) {
            process.env[key] = value;
        }
    }
}

function getMemoryMetrics() {
    const total = os.totalmem();
    const free = os.freemem();

    return {
        total_mb: round(total / 1024 / 1024, 1),
        free_mb: round(free / 1024 / 1024, 1),
        ram_avail_pct:
            total > 0 ? round((free / total) * 100, 1) : 0
    };
}

async function getDiskMetrics() {
    try {
        const { stdout } = await execFileAsync(
            'df',
            ['-Pk', ROOT],
            { timeout: 5000 }
        );

        const lines = stdout.trim().split(/\r?\n/);
        const row = lines[lines.length - 1].trim().split(/\s+/);

        if (row.length < 6) {
            throw new Error('Unexpected df output');
        }

        const totalKb = Number(row[1]);
        const usedKb = Number(row[2]);
        const freeKb = Number(row[3]);

        return {
            disk_total_mb: round(totalKb / 1024, 1),
            disk_used_mb: round(usedKb / 1024, 1),
            disk_mb: round(freeKb / 1024, 1)
        };
    } catch (error) {
        return {
            disk_total_mb: 0,
            disk_used_mb: 0,
            disk_mb: 0,
            error: error.message
        };
    }
}

async function directorySizeBytes(directory) {
    if (!fs.existsSync(directory)) {
        return 0;
    }

    try {
        const { stdout } = await execFileAsync(
            'du',
            ['-sk', directory],
            { timeout: 10000 }
        );

        const kb = Number.parseInt(stdout.trim().split(/\s+/)[0], 10);

        return Number.isFinite(kb) ? kb * 1024 : 0;
    } catch {
        return 0;
    }
}

async function countFiles(directory) {
    if (!fs.existsSync(directory)) {
        return 0;
    }

    try {
        const { stdout } = await execFileAsync(
            'find',
            [directory, '-type', 'f'],
            {
                timeout: 10000,
                maxBuffer: 4 * 1024 * 1024
            }
        );

        const text = stdout.trim();

        return text ? text.split(/\r?\n/).length : 0;
    } catch {
        return 0;
    }
}

async function getPm2Metrics() {
    if (!(await commandExists('pm2'))) {
        return {
            available: false,
            processes: [],
            error: 'pm2 command not found'
        };
    }

    try {
        const { stdout } = await execFileAsync(
            'pm2',
            ['jlist'],
            {
                timeout: 10000,
                maxBuffer: 16 * 1024 * 1024
            }
        );

        const raw = JSON.parse(stdout);

        const processes = raw.map(process => ({
            name:
                process.name ||
                process.pm2_env?.name ||
                'unknown',

            status:
                process.pm2_env?.status ||
                'unknown',

            pid:
                Number(process.pid) || 0,

            cpu_pct:
                Number(process.monit?.cpu) || 0,

            memory_mb:
                round(
                    (Number(process.monit?.memory) || 0) /
                    1024 /
                    1024,
                    1
                ),

            restarts:
                Number(process.pm2_env?.restart_time) || 0,

            unstable_restarts:
                Number(process.pm2_env?.unstable_restarts) || 0,

            uptime_ms:
                process.pm2_env?.pm_uptime
                    ? Math.max(
                        0,
                        Date.now() -
                        Number(process.pm2_env.pm_uptime)
                    )
                    : 0
        }));

        return {
            available: true,
            processes
        };
    } catch (error) {
        return {
            available: false,
            processes: [],
            error: error.message
        };
    }
}

function checkHealth(url, timeoutMs) {
    return new Promise(resolve => {
        let parsed;

        try {
            parsed = new URL(url);
        } catch (error) {
            resolve({
                ok: false,
                status: 0,
                latency_ms: 0,
                reason: `Invalid health URL: ${error.message}`
            });
            return;
        }

        const transport =
            parsed.protocol === 'https:' ? https : http;

        const started = Date.now();

        const request = transport.get(
            parsed,
            {
                timeout: timeoutMs,
                headers: {
                    'user-agent': 'cybra-metrics/1.0'
                }
            },
            response => {
                response.resume();

                const latency = Date.now() - started;
                const ok =
                    response.statusCode >= 200 &&
                    response.statusCode < 300;

                resolve({
                    ok,
                    status: response.statusCode || 0,
                    latency_ms: latency,
                    reason: ok
                        ? 'HTTP health check passed'
                        : `HTTP ${response.statusCode || 0}`
                });
            }
        );

        request.on('timeout', () => {
            request.destroy(
                new Error(`Timeout after ${timeoutMs}ms`)
            );
        });

        request.on('error', error => {
            resolve({
                ok: false,
                status: 0,
                latency_ms: Date.now() - started,
                reason: error.message
            });
        });
    });
}

function readKeyValueState(file) {
    const output = {};

    if (!fileExists(file)) {
        return output;
    }

    try {
        const text = fs.readFileSync(file, 'utf8');

        for (const line of text.split(/\r?\n/)) {
            const separator = line.indexOf('=');

            if (separator < 1) {
                continue;
            }

            const key = line.slice(0, separator).trim();
            const value = line.slice(separator + 1).trim();

            output[key] = value;
        }
    } catch {
        return {};
    }

    return output;
}

function stateItem(color, reason, details = {}) {
    return {
        color,
        reason,
        ...details
    };
}

function countColors(items) {
    const colors = {
        green: 0,
        yellow: 0,
        red: 0,
        black: 0
    };

    for (const item of Object.values(items)) {
        const color = item?.color;

        if (Object.hasOwn(colors, color)) {
            colors[color] += 1;
        }
    }

    return colors;
}

function overallFromItems(items) {
    const values = Object.values(items);

    const weights = {
        green: 100,
        yellow: 70,
        red: 25,
        black: 0
    };

    if (values.length === 0) {
        return {
            percent: 0,
            color: 'black'
        };
    }

    const total = values.reduce(
        (sum, item) => sum + (weights[item.color] ?? 0),
        0
    );

    const percent = round(total / values.length, 1);

    let color = 'green';

    if (values.some(item => item.color === 'black')) {
        color = 'black';
    } else if (values.some(item => item.color === 'red')) {
        color = 'red';
    } else if (values.some(item => item.color === 'yellow')) {
        color = 'yellow';
    }

    return {
        percent,
        color
    };
}

function createStage(items, overall, pm2) {
    const required = REQUIRED_PM2.map(name =>
        pm2.processes.find(process => process.name === name)
    );

    const allRequiredPresent =
        required.length > 0 &&
        required.every(Boolean);

    const allRequiredOnline =
        allRequiredPresent &&
        required.every(process => process.status === 'online');

    let stage = 1;
    let name = 'bootstrapping';

    if (pm2.available) {
        stage = 2;
        name = 'process-manager-online';
    }

    if (allRequiredPresent) {
        stage = 3;
        name = 'services-discovered';
    }

    if (allRequiredOnline) {
        stage = 4;
        name = 'services-online';
    }

    if (
        allRequiredOnline &&
        items.openid_health?.color === 'green' &&
        overall.color === 'green'
    ) {
        stage = 5;
        name = 'ready';
    }

    return {
        stage,
        name,
        gates_pass: stage === 5,
        updated_at: timestamp()
    };
}

async function collect() {
    const generatedAt = timestamp();

    const [
        pm2,
        disk,
        logsBytes,
        queueFiles,
        health
    ] = await Promise.all([
        getPm2Metrics(),
        getDiskMetrics(),
        directorySizeBytes(path.join(HOME, '.pm2', 'logs')),
        countFiles(path.join(ROOT, 'queue')),
        checkHealth(CONFIG.healthUrl, CONFIG.healthTimeoutMs)
    ]);

    const memory = getMemoryMetrics();
    const watchdog = readKeyValueState(WATCHDOG_STATE);

    const items = {};

    if (!pm2.available) {
        items.pm2 = stateItem(
            'black',
            pm2.error || 'PM2 metrics unavailable'
        );
    } else {
        items.pm2 = stateItem(
            'green',
            `${pm2.processes.length} PM2 process(es) discovered`
        );
    }

    for (const requiredName of REQUIRED_PM2) {
        const process = pm2.processes.find(
            candidate => candidate.name === requiredName
        );

        if (!process) {
            items[`pm2:${requiredName}`] = stateItem(
                'black',
                'Required PM2 process not found'
            );
        } else if (process.status !== 'online') {
            items[`pm2:${requiredName}`] = stateItem(
                'red',
                `PM2 status is ${process.status}`,
                {
                    pid: process.pid,
                    restarts: process.restarts
                }
            );
        } else if (process.unstable_restarts > 0) {
            items[`pm2:${requiredName}`] = stateItem(
                'yellow',
                `${process.unstable_restarts} unstable restart(s)`,
                {
                    pid: process.pid,
                    restarts: process.restarts,
                    cpu_pct: process.cpu_pct,
                    memory_mb: process.memory_mb
                }
            );
        } else {
            items[`pm2:${requiredName}`] = stateItem(
                'green',
                'PM2 process online',
                {
                    pid: process.pid,
                    restarts: process.restarts,
                    cpu_pct: process.cpu_pct,
                    memory_mb: process.memory_mb
                }
            );
        }
    }

    items.openid_health = stateItem(
        health.ok ? 'green' : 'red',
        health.reason,
        {
            url: CONFIG.healthUrl,
            http_status: health.status,
            latency_ms: health.latency_ms
        }
    );

    if (memory.ram_avail_pct <= CONFIG.ramRedPct) {
        items.ram = stateItem(
            'red',
            `Only ${memory.ram_avail_pct}% RAM available`
        );
    } else if (memory.ram_avail_pct <= CONFIG.ramYellowPct) {
        items.ram = stateItem(
            'yellow',
            `${memory.ram_avail_pct}% RAM available`
        );
    } else {
        items.ram = stateItem(
            'green',
            `${memory.ram_avail_pct}% RAM available`
        );
    }

    if (disk.error) {
        items.disk = stateItem('black', disk.error);
    } else if (disk.disk_mb <= CONFIG.diskRedMb) {
        items.disk = stateItem(
            'red',
            `${disk.disk_mb} MB disk available`
        );
    } else if (disk.disk_mb <= CONFIG.diskYellowMb) {
        items.disk = stateItem(
            'yellow',
            `${disk.disk_mb} MB disk available`
        );
    } else {
        items.disk = stateItem(
            'green',
            `${disk.disk_mb} MB disk available`
        );
    }

    const logsMb = round(logsBytes / 1024 / 1024, 1);

    if (logsMb >= CONFIG.logsRedMb) {
        items.logs = stateItem(
            'red',
            `PM2 logs use ${logsMb} MB`
        );
    } else if (logsMb >= CONFIG.logsYellowMb) {
        items.logs = stateItem(
            'yellow',
            `PM2 logs use ${logsMb} MB`
        );
    } else {
        items.logs = stateItem(
            'green',
            `PM2 logs use ${logsMb} MB`
        );
    }

    if (queueFiles >= CONFIG.queueRed) {
        items.queue = stateItem(
            'red',
            `${queueFiles} queued file(s)`
        );
    } else if (queueFiles >= CONFIG.queueYellow) {
        items.queue = stateItem(
            'yellow',
            `${queueFiles} queued file(s)`
        );
    } else {
        items.queue = stateItem(
            'green',
            `${queueFiles} queued file(s)`
        );
    }

    const cooldownUntil =
        Number(watchdog.COOLDOWN_UNTIL) || 0;

    const nowSeconds = Math.floor(Date.now() / 1000);

    if (cooldownUntil > nowSeconds) {
        items.self_heal = stateItem(
            'yellow',
            `Cooldown active for ${cooldownUntil - nowSeconds}s`,
            {
                restart_count:
                    Number(watchdog.RESTART_COUNT) || 0,

                fail_count:
                    Number(watchdog.FAIL_COUNT) || 0,

                cooldown_until: cooldownUntil
            }
        );
    } else if (Object.keys(watchdog).length > 0) {
        items.self_heal = stateItem(
            'green',
            'Self-heal active',
            {
                restart_count:
                    Number(watchdog.RESTART_COUNT) || 0,

                fail_count:
                    Number(watchdog.FAIL_COUNT) || 0
            }
        );
    } else {
        items.self_heal = stateItem(
            'yellow',
            'Health watchdog state unavailable'
        );
    }

    const colors = countColors(items);
    const overall = overallFromItems(items);

    const cpuTotal = round(
        pm2.processes.reduce(
            (sum, process) => sum + process.cpu_pct,
            0
        ),
        1
    );

    const pm2MemoryMb = round(
        pm2.processes.reduce(
            (sum, process) => sum + process.memory_mb,
            0
        ),
        1
    );

    const manifest = {
        schema_version: 1,
        generated_at: generatedAt,

        overall,
        colors,

        resources: {
            ...memory,
            ...disk,

            cpu_count: os.cpus().length,
            load_average: os.loadavg().map(value => round(value, 2)),

            pm2_cpu_pct: cpuTotal,
            pm2_memory_mb: pm2MemoryMb,
            pm2_logs_mb: logsMb,

            queue_files: queueFiles
        },

        services: pm2.processes,

        health: {
            openid: health
        },

        self_heal: {
            fail_count:
                Number(watchdog.FAIL_COUNT) || 0,

            restart_count:
                Number(watchdog.RESTART_COUNT) || 0,

            window_start:
                Number(watchdog.WINDOW_START) || 0,

            cooldown_until:
                cooldownUntil
        },

        items,

        needs_cleanup:
            items.logs.color === 'yellow' ||
            items.logs.color === 'red' ||
            items.disk.color === 'yellow' ||
            items.disk.color === 'red',

        needs_throttle:
            items.ram.color === 'yellow' ||
            items.ram.color === 'red' ||
            items.queue.color === 'yellow' ||
            items.queue.color === 'red'
    };

    const stage = createStage(items, overall, pm2);

    atomicWriteJSON(MANIFEST_FILE, manifest);
    atomicWriteJSON(STAGE_FILE, stage);

    log(
        'INFO',
        `manifest=${overall.percent}%/${overall.color} ` +
        `stage=${stage.stage} ` +
        `health=${health.ok ? 'ok' : 'fail'}`
    );
}

async function tick() {
    if (running || shuttingDown) {
        return;
    }

    running = true;

    try {
        await collect();
    } catch (error) {
        log(
            'ERROR',
            error && error.stack
                ? error.stack
                : String(error)
        );
    } finally {
        running = false;
    }
}

async function shutdown(signal) {
    if (shuttingDown) {
        return;
    }

    shuttingDown = true;
    log('INFO', `Received ${signal}, stopping`);

    while (running) {
        await new Promise(resolve => setTimeout(resolve, 100));
    }

    process.exit(0);
}

async function main() {
    await loadDotEnv();

    fs.mkdirSync(STATE_DIR, {
        recursive: true,
        mode: 0o700
    });

    log(
        'INFO',
        `CYBRA metrics generator started, interval=${CONFIG.intervalMs}ms`
    );

    await tick();

    const timer = setInterval(tick, CONFIG.intervalMs);
    timer.unref();

    process.on('SIGINT', () => shutdown('SIGINT'));
    process.on('SIGTERM', () => shutdown('SIGTERM'));
}

main().catch(error => {
    log(
        'FATAL',
        error && error.stack
            ? error.stack
            : String(error)
    );

    process.exit(1);
});
