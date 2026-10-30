#!/usr/bin/env python3
"""CYBRA Hot-Reload Watcher.

Стежить за контролерами і рестартить PM2-процес, коли файл змінився.
Дебаунс 5с, ліміт 1 рестарт/файл/30с. Не робить kill.
"""
import os, sys, time, json, subprocess, logging, signal
from pathlib import Path

HOME = Path(os.path.expanduser("~"))
PM2_HOME = Path(os.environ.get("PM2_HOME", HOME / ".pm2"))
LOGDIR = PM2_HOME / "logs"; LOGDIR.mkdir(parents=True, exist_ok=True)
LOG = LOGDIR / "hotreload.log"
logging.basicConfig(level=logging.INFO,
    format="[%(asctime)s] %(levelname)s %(message)s",
    handlers=[logging.FileHandler(LOG), logging.StreamHandler(sys.stdout)])
log = logging.getLogger("hr")

WATCH = {
    "cybra-neuro-ctrl":        [HOME/"CYBRA"/"bin"/"cybra_neuro_controller.py"],
    "cybra-evo-ctrl":          [HOME/"CYBRA"/"bin"/"cybra_evo_controller.py"],
    "cybra-evolution-ctrl":    [HOME/"CYBRA"/"bin"/"cybra_evolution_controller.py"],
    "cybra-resurrection-ctrl": [HOME/"CYBRA"/"bin"/"cybra_resurrection_controller.py"],
    "cybra-oracle-ctrl":       [HOME/"CYBRA"/"bin"/"cybra_oracle_controller.py"],
    "cybra-git-sync":          [HOME/"bin"/"autopilot-sync.sh",
                                HOME/"CYBRA"/"scripts"/"autopilot-sync.sh"],
    "cybra-token-guard":       [HOME/"CYBRA"/"bin"/"cybra_token_guard_loop.sh"],
    "cybra-complexity":        [HOME/"CYBRA"/"bin"/"cybra_complexity_loop.sh"],
}
DEBOUNCE = 5.0
MIN_INTERVAL = 30.0
TICK = 2.0

state = {}   # path -> {"mtime": x, "pending_at": t, "last_restart": t}

def snapshot():
    cur = {}
    for name, paths in WATCH.items():
        for p in paths:
            if p.exists():
                try: cur[str(p)] = p.stat().st_mtime
                except Exception: pass
    return cur

def restart(name):
    try:
        subprocess.run(["pm2","restart",name], check=False, timeout=20,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        log.info("restart %s", name)
        return True
    except Exception as e:
        log.warning("restart %s failed: %s", name, e); return False

def loop():
    log.info("HOTRELOAD start (%d processes watched)", len(WATCH))
    stop = {"f": False}
    def sig(s, f): log.info("signal %s", s); stop["f"]=True
    signal.signal(signal.SIGTERM, sig); signal.signal(signal.SIGINT, sig)

    first = snapshot()
    for p, m in first.items(): state[p] = {"mtime": m, "pending_at": None, "last_restart": 0}

    while not stop["f"]:
        now = time.time()
        cur = snapshot()
        # нові зміни
        for p, m in cur.items():
            st = state.get(p, {"mtime": 0, "pending_at": None, "last_restart": 0})
            if m > st["mtime"]:
                st["mtime"] = m
                st["pending_at"] = now
                log.info("change detected: %s", p)
            state[p] = st
        # дебаунс
        for name, paths in WATCH.items():
            trigger = None
            for p in paths:
                st = state.get(str(p))
                if not st: continue
                if st["pending_at"] and (now - st["pending_at"]) >= DEBOUNCE:
                    if now - st["last_restart"] >= MIN_INTERVAL:
                        trigger = p; st["last_restart"] = now; st["pending_at"] = None
                        break
                    else:
                        st["pending_at"] = None  # пропущено через rate limit
            if trigger:
                restart(name)
        time.sleep(TICK)
    log.info("HOTRELOAD stop")

if __name__ == "__main__":
    loop()
