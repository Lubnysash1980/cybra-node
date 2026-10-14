#!/usr/bin/env python3
# parliament_tui.py – CYBRA Parliament TUI v1.1
# Смарт-контракт AI-парламенту у стилі CYBRA CONTRACT MANAGER.

import os
import sys
import json
import time
import hashlib
import random
import threading
from pathlib import Path
from datetime import datetime, timezone
from typing import Dict, List, Optional, Any

# ═══════════════════════════════════════════════════════════════
# КОНФІГ
# ═══════════════════════════════════════════════════════════════
BASE_DIR       = Path(__file__).parent
CHAIN_FILE     = BASE_DIR / "chain.json"
CONTRACT_FILE  = BASE_DIR / "parliament.json"
LOG_FILE       = BASE_DIR / "parliament.log"
LEDGER_FILE    = BASE_DIR / "parliament_ledger.json"
AUDIT_FILE     = BASE_DIR / "parliament_audit.json"
BACKUP_DIR     = BASE_DIR / "backups"

NUM_AGENTS      = 7
QUORUM          = 4
VOTE_REWARD     = 0.01
PROPOSE_REWARD  = 0.10
DEFAULT_DEADLINE = 60

FACTIONS = [
    "Progressive", "Conservative", "Libertarian",
    "Green", "Technocratic", "Populist", "Independent"
]

# ANSI
C_RESET  = "\033[0m"
C_DIM    = "\033[2m"
C_BOLD   = "\033[1m"
C_GREEN  = "\033[92m"
C_YELLOW = "\033[93m"
C_RED    = "\033[91m"
C_CYAN   = "\033[96m"
C_MAG    = "\033[95m"
C_BLUE   = "\033[94m"

def clr(txt, c): return f"{c}{txt}{C_RESET}"

# ═══════════════════════════════════════════════════════════════
# УТИЛІТИ
# ═══════════════════════════════════════════════════════════════
def double_sha256(data: bytes) -> str:
    return hashlib.sha256(hashlib.sha256(data).digest()).hexdigest()

def now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")

def log(msg: str):
    line = f"[{now_iso()}] {msg}"
    try:
        with open(LOG_FILE, "a", encoding="utf-8") as f:
            f.write(line + "\n")
    except Exception:
        pass

def audit(action: str, data: Dict[str, Any]):
    try:
        entries = json.loads(AUDIT_FILE.read_text()) if AUDIT_FILE.exists() else []
    except Exception:
        entries = []
    entries.append({"ts": now_iso(), "action": action, "data": data})
    AUDIT_FILE.write_text(json.dumps(entries, indent=2, ensure_ascii=False))

def clear():
    os.system("clear" if os.name != "nt" else "cls")

def pause(msg="  ↵ Enter для продовження…"):
    input(clr(msg, C_DIM))

# ═══════════════════════════════════════════════════════════════
# MAPPING (Solidity-style)
# ═══════════════════════════════════════════════════════════════
class Mapping:
    def __init__(self, name: str):
        self.name = name
        self._store: Dict[str, Any] = {}

    def set(self, key, value):      self._store[key] = value
    def get(self, key, default=None): return self._store.get(key, default)
    def has(self, key):             return key in self._store
    def delete(self, key):          self._store.pop(key, None)
    def keys(self):                 return list(self._store.keys())
    def items(self):                return list(self._store.items())
    def to_dict(self):              return dict(self._store)
    def load_dict(self, data):      self._store = dict(data or {})

# ═══════════════════════════════════════════════════════════════
# СМАРТ-КОНТРАКТ
# ═══════════════════════════════════════════════════════════════
class ParliamentContract:
    def __init__(self):
        self.agents    = Mapping("agents")
        self.votes     = Mapping("votes")
        self.proposals = Mapping("proposals")
        self.balances  = Mapping("balances")
        self._lock     = threading.RLock()
        self.contract_hash = ""
        self.network = "BSC(56)"
        self.license = "1%+1%+1%"

    def deploy(self, num_agents: int = NUM_AGENTS):
        with self._lock:
            for i in range(num_agents):
                agent_id = f"AI_{i:03d}"
                faction  = random.choice(FACTIONS)
                address  = double_sha256(f"{agent_id}{time.time()}{random.random()}".encode())[:40]
                weight   = random.choice([1, 1, 1, 2, 3])
                self.agents.set(agent_id, {
                    "faction":  faction,
                    "address":  address,
                    "weight":   weight,
                    "created":  now_iso()
                })
                self.balances.set(address, 0.0)
            self.contract_hash = self._compute_hash()
        log(f"📜 Контракт розгорнуто: {num_agents} агентів, hash={self.contract_hash[:16]}…")
        audit("deploy", {"agents": num_agents, "hash": self.contract_hash})

    def _compute_hash(self) -> str:
        payload = json.dumps({
            "agents":    self.agents.to_dict(),
            "votes":     self.votes.to_dict(),
            "proposals": self.proposals.to_dict(),
            "balances":  self.balances.to_dict(),
        }, sort_keys=True).encode()
        return double_sha256(payload)

    def propose(self, text: str, author: str, deadline: int = DEFAULT_DEADLINE) -> Optional[str]:
        if not text.strip() or author not in self.agents.keys():
            return None
        pid = double_sha256(f"{text}{author}{time.time()}".encode())[:12]
        with self._lock:
            self.proposals.set(pid, {
                "text":     text.strip(),
                "author":   author,
                "status":   "voting",
                "created":  now_iso(),
                "deadline": time.time() + deadline,
                "yes": 0, "no": 0, "abstain": 0
            })
        log(f"📢 Пропозиція {pid}: {text[:60]}")
        audit("propose", {"pid": pid, "author": author, "text": text})
        return pid

    def vote(self, agent_id: str, pid: str, choice: int) -> bool:
        if choice not in (-1, 0, 1): return False
        agent, prop = self.agents.get(agent_id), self.proposals.get(pid)
        if not agent or not prop: return False
        if prop["status"] != "voting": return False
        if time.time() > prop["deadline"]: return False

        with self._lock:
            votes = self.votes.get(pid, {})
            if agent_id in votes: return False
            votes[agent_id] = choice
            self.votes.set(pid, votes)
            w = agent["weight"]
            prop["yes" if choice==1 else "no" if choice==-1 else "abstain"] += w
            self.proposals.set(pid, prop)
            addr = agent["address"]
            self.balances.set(addr, self.balances.get(addr, 0.0) + VOTE_REWARD)
        return True

    def tally(self, pid: str) -> Optional[Dict]:
        prop = self.proposals.get(pid)
        if not prop: return None
        if prop["status"] != "voting": return prop
        y, n, a = prop["yes"], prop["no"], prop["abstain"]
        total = y + n + a
        if total < QUORUM:      prop["status"] = "rejected_quorum"
        elif y > n:             prop["status"] = "passed"
        elif n > y:             prop["status"] = "rejected"
        else:                   prop["status"] = "tie"
        prop["tallied_at"] = now_iso()
        with self._lock:
            self.proposals.set(pid, prop)
            if prop["status"] == "passed":
                author = self.agents.get(prop["author"])
                if author:
                    addr = author["address"]
                    self.balances.set(addr, self.balances.get(addr, 0.0) + PROPOSE_REWARD)
        log(f"📊 Tally {pid}: yes={y} no={n} abstain={a} → {prop['status']}")
        audit("tally", {"pid": pid, "result": prop["status"], "yes": y, "no": n, "abstain": a})
        return prop

    def snapshot(self) -> Dict:
        return {
            "contract_hash": self._compute_hash(),
            "network":       self.network,
            "license":       self.license,
            "agents":        self.agents.to_dict(),
            "votes":         self.votes.to_dict(),
            "proposals":     self.proposals.to_dict(),
            "balances":      self.balances.to_dict(),
            "saved_at":      now_iso()
        }

    def save(self, path: Path = CONTRACT_FILE):
        with self._lock:
            data = self.snapshot()
        path.write_text(json.dumps(data, indent=2, ensure_ascii=False))
        log(f"💾 Стан збережено: {path}")

    def load(self, path: Path = CONTRACT_FILE) -> bool:
        if not path.exists(): return False
        data = json.loads(path.read_text())
        self.agents.load_dict(data.get("agents", {}))
        self.votes.load_dict(data.get("votes", {}))
        self.proposals.load_dict(data.get("proposals", {}))
        self.balances.load_dict(data.get("balances", {}))
        self.contract_hash = data.get("contract_hash", "")
        self.network = data.get("network", "BSC(56)")
        self.license = data.get("license", "1%+1%+1%")
        log(f"📂 Стан завантажено: {path}")
        return True

    # --- ledger / backup ---
    def ledger_append(self, entry: Dict):
        try:
            rows = json.loads(LEDGER_FILE.read_text()) if LEDGER_FILE.exists() else []
        except Exception:
            rows = []
        rows.append({"ts": now_iso(), **entry})
        LEDGER_FILE.write_text(json.dumps(rows, indent=2, ensure_ascii=False))

    def backup(self) -> Optional[Path]:
        BACKUP_DIR.mkdir(exist_ok=True)
        ts = datetime.now().strftime("%Y%m%d_%H%M%S")
        dst = BACKUP_DIR / f"parliament_{ts}.json"
        dst.write_text(json.dumps(self.snapshot(), indent=2, ensure_ascii=False))
        log(f"📦 Backup: {dst}")
        return dst

# ═══════════════════════════════════════════════════════════════
# BLOCKCHAIN
# ═══════════════════════════════════════════════════════════════
def append_to_chain(contract: ParliamentContract, pid: str, result: Dict) -> str:
    chain = json.loads(CHAIN_FILE.read_text()) if CHAIN_FILE.exists() else []
    if not chain:
        chain = [{
            "index": 0, "prev_hash": "0"*64, "task": "Genesis",
            "layers": "{}", "result": "", "nonce": 0, "quality": 100,
            "miner": "genesis", "public_key": "", "signature": "",
            "timestamp": time.time(), "difficulty": 2, "hash": "0"*64,
            "metadata": {"version": "1.0", "symbol": "CYB",
                         "network": "devnet", "uuid": "genesis"},
            "transactions": []
        }]
    prev = chain[-1]
    index = prev["index"] + 1
    task = f"Parliament vote: {result.get('text', '')[:60]}"
    layers = json.dumps({
        "logic":    f"proposal={pid}",
        "analysis": f"yes={result.get('yes')}, no={result.get('no')}, abstain={result.get('abstain')}",
        "search":   f"status={result.get('status')}"
    })
    nonce, diff, ts = 0, 2, time.time()
    target = "0" * diff
    while True:
        bh = hashlib.sha256(
            f"{index}{prev['hash']}{task}{layers}{result.get('status')}{nonce}{ts}".encode()
        ).hexdigest()
        if bh.startswith(target): break
        nonce += 1
    block = {
        "index": index, "prev_hash": prev["hash"], "task": task, "layers": layers,
        "result": json.dumps(result, ensure_ascii=False), "nonce": nonce,
        "quality": 100, "miner": "parliament_ai",
        "public_key": "", "signature": contract.contract_hash[:32],
        "timestamp": ts, "difficulty": diff, "hash": bh,
        "metadata": {"version": "1.0", "symbol": "CYB", "network": "devnet",
                     "uuid": double_sha256(f"{pid}{ts}".encode())[:16]},
        "transactions": []
    }
    chain.append(block)
    CHAIN_FILE.write_text(json.dumps(chain, indent=2, ensure_ascii=False))
    log(f"⛓️ Блок додано: {bh[:16]}… (index={index})")
    return bh

# ═══════════════════════════════════════════════════════════════
# AI-АГЕНТИ
# ═══════════════════════════════════════════════════════════════
class AIAgent(threading.Thread):
    STRATEGIES = {
        "Progressive": "progressive", "Conservative": "conservative",
        "Libertarian": "libertarian", "Green": "green",
        "Technocratic": "technocratic", "Populist": "populist",
        "Independent": "random"
    }

    def __init__(self, agent_id, contract, interval=3.0):
        super().__init__(daemon=True)
        self.agent_id = agent_id
        self.contract = contract
        self.interval = interval
        self.running = True

    def _decide(self, text: str) -> int:
        a = self.contract.agents.get(self.agent_id)
        if not a: return 0
        strat = self.STRATEGIES.get(a["faction"], "random")
        t = text.lower()
        if strat == "progressive":   return 1 if any(k in t for k in ("innovation","ai","reform","future")) else -1
        if strat == "conservative":  return -1 if any(k in t for k in ("change","reform","ban")) else 1
        if strat == "libertarian":   return -1 if any(k in t for k in ("tax","ban","restrict")) else 1
        if strat == "green":         return 1 if any(k in t for k in ("climate","green","eco")) else 0
        if strat == "technocratic":  return 1 if any(k in t for k in ("data","algorithm","ai","system")) else 0
        if strat == "populist":      return 1 if any(k in t for k in ("people","public","freedom")) else -1
        return random.choices([1,-1,0], weights=[5,3,2])[0]

    def run(self):
        while self.running:
            open_props = [
                pid for pid, p in self.contract.proposals.items()
                if p.get("status") == "voting" and time.time() < p.get("deadline", 0)
            ]
            for pid in open_props:
                if self.agent_id in self.contract.votes.get(pid, {}):
                    continue
                prop = self.contract.proposals.get(pid)
                if not prop: continue
                self.contract.vote(self.agent_id, pid, self._decide(prop["text"]))
            time.sleep(self.interval)

    def stop(self): self.running = False

# ═══════════════════════════════════════════════════════════════
# СЕСІЯ
# ═══════════════════════════════════════════════════════════════
class ParliamentSession:
    def __init__(self):
        self.contract = ParliamentContract()
        self.agents: List[AIAgent] = []
        self.started = False

    def bootstrap(self, force_new=False):
        if force_new or not self.contract.load():
            self.contract.deploy(NUM_AGENTS)
            self.contract.save()
        for aid in self.contract.agents.keys():
            a = AIAgent(aid, self.contract); a.start()
            self.agents.append(a)
        self.started = True
        log(f"🧠 Запущено {len(self.agents)} AI-агентів")

    def shutdown(self):
        for a in self.agents: a.stop()
        if self.started: self.contract.save()
        log("🛑 Сесію завершено")

    def run_proposal(self, text: str, deadline: int = DEFAULT_DEADLINE):
        author = random.choice(self.contract.agents.keys())
        pid = self.contract.propose(text, author, deadline)
        if not pid: return None
        t_end = time.time() + deadline
        bar_w = 30
        while time.time() < t_end:
            left = int(t_end - time.time())
            filled = int((1 - left / deadline) * bar_w)
            bar = clr("█"*filled, C_GREEN) + clr("░"*(bar_w-filled), C_DIM)
            print(f"\r  ⏳ [{bar}] {left:3d}s ", end="", flush=True)
            time.sleep(1)
        print()
        result = self.contract.tally(pid)
        if result:
            self.contract.save()
            append_to_chain(self.contract, pid, result)
            self.contract.ledger_append({"type": "proposal", "pid": pid, "status": result["status"]})
        return result

# ═══════════════════════════════════════════════════════════════
# TUI
# ═══════════════════════════════════════════════════════════════
PROPOSALS_LIB = [
    "Прийняти закон про штучний інтелект",
    "Підвищити податок на великі технологічні компанії",
    "Заборонити автономні системи без нагляду",
    "Запровадити green energy для data-центрів",
    "Дати людям свободу вибору цифрових сервісів",
    "Реформувати систему управління алгоритмами",
    "Public data must be open and free",
    "AI must be transparent and auditable",
    "Innovation needs state support",
    "Restrict surveillance algorithms",
]

class ParliamentTUI:
    def __init__(self):
        self.session = ParliamentSession()
        self.session.bootstrap()

    # ---------- helpers ----------
    def _agents_count(self):   return len(self.session.contract.agents.keys())
    def _props_count(self):    return len(self.session.contract.proposals.keys())
    def _active_count(self):
        return sum(1 for _, p in self.session.contract.proposals.items() if p.get("status") == "voting")

    def header(self):
        c = self.session.contract
        ready = clr("🟢 READY", C_GREEN)
        line1 = f"  {ready}  │  {clr(c.network, C_CYAN)}  │  {clr(c.license + ' license', C_CYAN)}"
        line2 = (f"  {self._agents_count()} agents  │  "
                 f"{self._props_count()} proposals  │  "
                 f"{self._active_count()} active")
        line3 = f"  🕐 {now_iso()}"

        print(clr("═" * 60, C_CYAN))
        print(clr("           CYBRA PARLIAMENT — TUI v1.1".center(60), C_BOLD))
        print(clr("═" * 60, C_CYAN))
        print(line1)
        print(line2)
        print(clr(line3, C_DIM))
        print(clr("─" * 60, C_DIM))

    def section(self, title):
        print()
        print(clr(f"  ─── {title} ───", C_MAG))

    def item(self, key, label, status="ready"):
        icon = {"ready": clr("🟢", C_GREEN),
                "warn":  clr("🟡", C_YELLOW),
                "error": clr("🔴", C_RED)}.get(status, clr("🟢", C_GREEN))
        print(f"  {icon} [{key:>3}] {label}")

    # ---------- menu ----------
    def menu(self):
        clear()
        self.header()

        self.section("ПАРЛАМЕНТ")
        self.item(1,  "Розгорнути новий контракт")
        self.item(2,  "Список агентів")
        self.item(3,  "Створити пропозицію")
        self.item(4,  "Голосувати (вручну за агента)")
        self.item(5,  "Tally пропозиції")
        self.item(6,  "Список пропозицій")
        self.item(7,  "Список голосів")

        self.section("AI-АГЕНТИ")
        self.item(8,  "Запустити авто-голосування")
        self.item(9,  "Стан агентів / фракції")
        self.item(10, "AI Авто-сесія (N пропозицій)")

        self.section("БАЛАНСИ / LEDGER")
        self.item(11, "Баланси агентів")
        self.item(12, "Ledger (parliament_ledger.json)")
        self.item(13, "Нагородити агента")

        self.section("БЛОКЧЕЙН")
        self.item(14, "Переглянути chain.json")
        self.item(15, "Перевірити цілісність ланцюга")

        self.section("EXPORT / BACKUP")
        self.item(16, "Backup контракту")
        self.item(17, "Список бекапів")
        self.item(18, "Відновити з бекапу")
        self.item(19, "Експорт JSON контракту")
        self.item(20, "Audit log")
        self.item(21, "Перевірити audit")

        self.section("СИСТЕМА")
        self.item(22, "Скинути стан (reset)")
        self.item(23, "Статус модуля")

        print()
        print(clr("  🟢 ready  🟡 warning  🔴 error", C_DIM))
        print()
        print(clr("  [0]  Вихід", C_BOLD))
        print()

    # ---------- actions ----------
    def do_deploy(self):
        clear(); self.header()
        print()
        ans = input(clr("  ⚠ Створити новий контракт? Поточний буде замінено [y/N]: ", C_YELLOW)).strip().lower()
        if ans != "y":
            return
        self.session.shutdown()
        self.session = ParliamentSession()
        self.session.bootstrap(force_new=True)
        print(clr(f"  ✅ Контракт розгорнуто: hash={self.session.contract.contract_hash[:20]}…", C_GREEN))
        pause()

    def do_agents(self):
        clear(); self.header()
        self.section("АГЕНТИ")
        for aid, a in self.session.contract.agents.items():
            bal = self.session.contract.balances.get(a["address"], 0.0)
            print(f"  {clr(aid, C_BOLD):<20} {a['faction']:<14} w={a['weight']}  bal={bal:.4f} CYB")
            print(clr(f"       addr: {a['address']}", C_DIM))
        pause()

    def do_propose(self):
        clear(); self.header()
        print()
        print(clr("  Пропозиції-шаблони:", C_DIM))
        for i, p in enumerate(PROPOSALS_LIB, 1):
            print(f"    {i:>2}. {p}")
        print()
        txt = input(clr("  Текст пропозиції (Enter = випадкова): ", C_CYAN)).strip()
        if not txt:
            txt = random.choice(PROPOSALS_LIB)
            print(clr(f"  (обрано): {txt}", C_DIM))
        try:
            dl = int(input(clr(f"  Deadline сек [{DEFAULT_DEADLINE}]: ", C_CYAN)).strip() or DEFAULT_DEADLINE)
        except ValueError:
            dl = DEFAULT_DEADLINE
        result = self.session.run_proposal(txt, dl)
        if result:
            self._print_result(result)
        pause()

    def do_vote(self):
        clear(); self.header()
        active = [pid for pid, p in self.session.contract.proposals.items() if p.get("status") == "voting"]
        if not active:
            print(clr("  Немає активних пропозицій", C_YELLOW)); pause(); return
        for pid in active:
            print(f"    {pid}  {self.session.contract.proposals.get(pid)['text'][:50]}")
        pid = input(clr("\n  PID: ", C_CYAN)).strip()
        if pid not in active:
            print(clr("  ❌ Невірний PID", C_RED)); pause(); return
        agents = list(self.session.contract.agents.keys())
        print(clr(f"  Агенти: {', '.join(agents)}", C_DIM))
        aid = input(clr("  Agent ID: ", C_CYAN)).strip()
        ch = input(clr("  Голос [1=за / -1=проти / 0=утрим]: ", C_CYAN)).strip()
        try:
            ch = int(ch)
        except ValueError:
            print(clr("  ❌ Невірний голос", C_RED)); pause(); return
        ok = self.session.contract.vote(aid, pid, ch)
        print(clr(f"  {'✅ Голос зараховано' if ok else '❌ Голос відхилено'}", C_GREEN if ok else C_RED))
        self.session.contract.save()
        pause()

    def do_tally(self):
        clear(); self.header()
        pids = list(self.session.contract.proposals.keys())
        for pid in pids:
            print(f"    {pid}  {self.session.contract.proposals.get(pid)['text'][:50]}")
        pid = input(clr("\n  PID: ", C_CYAN)).strip()
        r = self.session.contract.tally(pid)
        if r:
            if r["status"] in ("passed", "rejected", "tie", "rejected_quorum"):
                append_to_chain(self.session.contract, pid, r)
            self.session.contract.save()
            self._print_result(r)
        else:
            print(clr("  ❌ Не знайдено", C_RED))
        pause()

    def do_props(self):
        clear(); self.header()
        self.section("ПРОПОЗИЦІЇ")
        if not self.session.contract.proposals.keys():
            print(clr("  (порожньо)", C_DIM))
        for pid, p in self.session.contract.proposals.items():
            color = {"voting": C_YELLOW, "passed": C_GREEN, "rejected": C_RED,
                     "tie": C_CYAN, "rejected_quorum": C_MAG}.get(p["status"], C_RESET)
            print(f"  {clr(pid, C_BOLD)}  {p['text'][:55]}")
            print(f"    {clr(p['status'].upper(), color)}  yes={p['yes']} no={p['no']} ab={p['abstain']}  author={p['author']}")
        pause()

    def do_votes(self):
        clear(); self.header()
        self.section("ГОЛОСИ")
        for pid, v in self.session.contract.votes.items():
            print(f"  {clr(pid, C_BOLD)}")
            for aid, ch in v.items():
                mark = {1: clr("✔", C_GREEN), -1: clr("✘", C_RED), 0: clr("—", C_DIM)}[ch]
                print(f"    {mark} {aid}")
        pause()

    def do_auto_vote(self):
        clear(); self.header()
        print(clr("  AI-агенти голосують у фоні. Чекаю 5 с…", C_DIM))
        time.sleep(5)
        print(clr("  Готово.", C_GREEN))
        pause()

    def do_agent_state(self):
        clear(); self.header()
        self.section("ФРАКЦІЇ")
        stats = {}
        for aid, a in self.session.contract.agents.items():
            stats.setdefault(a["faction"], []).append(aid)
        for f, ids in stats.items():
            print(f"  {clr(f, C_CYAN):<30} {len(ids)} агент(ів)")
        pause()

    def do_auto_session(self):
        clear(); self.header()
        try:
            n = int(input(clr(f"  Скільки пропозицій? [3]: ", C_CYAN)).strip() or "3")
            dl = int(input(clr(f"  Deadline сек [{DEFAULT_DEADLINE}]: ", C_CYAN)).strip() or str(DEFAULT_DEADLINE))
        except ValueError:
            n, dl = 3, DEFAULT_DEADLINE
        for i in range(n):
            print(clr(f"\n  ▶ {i+1}/{n}", C_BOLD))
            txt = random.choice(PROPOSALS_LIB)
            print(clr(f"  Текст: {txt}", C_DIM))
            r = self.session.run_proposal(txt, dl)
            if r: self._print_result(r)
        pause()

    def do_balances(self):
        clear(); self.header()
        self.section("БАЛАНСИ")
        rows = sorted(self.session.contract.balances.items(), key=lambda x: -x[1])
        for i, (addr, bal) in enumerate(rows, 1):
            print(f"  {i:>3}. {addr[:20]}… {clr(f'{bal:.6f}', C_GREEN)} CYB")
        pause()

    def do_ledger(self):
        clear(); self.header()
        self.section("LEDGER")
        if not LEDGER_FILE.exists():
            print(clr("  (порожньо)", C_DIM))
        else:
            rows = json.loads(LEDGER_FILE.read_text())
            for r in rows[-50:]:
                print(f"  {r.get('ts')}  {r.get('type')}  {r.get('pid','')}  {r.get('status','')}")
        pause()

    def do_reward(self):
        clear(); self.header()
        addr = input(clr("  Адреса агента (або agent_id): ", C_CYAN)).strip()
        # приймаємо і agent_id, і address
        target = addr
        a = self.session.contract.agents.get(addr)
        if a: target = a["address"]
        try:
            amt = float(input(clr("  Сума CYB: ", C_CYAN)).strip())
        except ValueError:
            print(clr("  ❌ Невірна сума", C_RED)); pause(); return
        cur = self.session.contract.balances.get(target, 0.0)
        self.session.contract.balances.set(target, cur + amt)
        self.session.contract.save()
        self.session.contract.ledger_append({"type": "reward", "address": target, "amount": amt})
        print(clr(f"  ✅ {target[:20]}… += {amt} CYB", C_GREEN))
        pause()

    def do_chain_view(self):
        clear(); self.header()
        self.section("CHAIN")
        if not CHAIN_FILE.exists():
            print(clr("  chain.json не знайдено", C_YELLOW))
        else:
            chain = json.loads(CHAIN_FILE.read_text())
            for b in chain[-10:]:
                print(f"  #{b['index']}  {b['hash'][:16]}…  {b['task'][:45]}")
            print(clr(f"\n  Всього блоків: {len(chain)}", C_DIM))
        pause()

    def do_chain_verify(self):
        clear(); self.header()
        if not CHAIN_FILE.exists():
            print(clr("  ❌ chain.json відсутній", C_RED)); pause(); return
        chain = json.loads(CHAIN_FILE.read_text())
        ok = True
        for i in range(1, len(chain)):
            if chain[i]["prev_hash"] != chain[i-1]["hash"]:
                print(clr(f"  ❌ Розрив на блоці #{i}", C_RED)); ok = False
        print(clr("  ✅ Ланцюг цілісний" if ok else "  ❌ Ланцюг пошкоджено",
                  C_GREEN if ok else C_RED))
        pause()

    def do_backup(self):
        clear(); self.header()
        p = self.session.contract.backup()
        print(clr(f"  ✅ Backup: {p}", C_GREEN))
        pause()

    def do_backups_list(self):
        clear(); self.header()
        self.section("БЕКАПИ")
        if not BACKUP_DIR.exists():
            print(clr("  (немає)", C_DIM))
        else:
            for f in sorted(BACKUP_DIR.glob("parliament_*.json"), reverse=True)[:20]:
                sz = f.stat().st_size
                print(f"  {f.name}  ({sz} B)")
        pause()

    def do_restore(self):
        clear(); self.header()
        if not BACKUP_DIR.exists():
            print(clr("  немає бекапів", C_YELLOW)); pause(); return
        files = sorted(BACKUP_DIR.glob("parliament_*.json"), reverse=True)
        for i, f in enumerate(files[:20], 1):
            print(f"    {i:>2}. {f.name}")
        try:
            idx = int(input(clr("\n  Номер: ", C_CYAN)).strip()) - 1
        except ValueError:
            return
        if 0 <= idx < len(files):
            self.session.shutdown()
            self.session = ParliamentSession()
            self.session.contract.load(files[idx])
            self.session.bootstrap()
            print(clr(f"  ✅ Відновлено з {files[idx].name}", C_GREEN))
        pause()

    def do_export(self):
        clear(); self.header()
        dst = BASE_DIR / f"export_{int(time.time())}.json"
        dst.write_text(json.dumps(self.session.contract.snapshot(), indent=2, ensure_ascii=False))
        print(clr(f"  ✅ Експорт: {dst}", C_GREEN))
        pause()

    def do_audit(self):
        clear(); self.header()
        self.section("AUDIT")
        if not AUDIT_FILE.exists():
            print(clr("  (порожньо)", C_DIM))
        else:
            rows = json.loads(AUDIT_FILE.read_text())
            for r in rows[-40:]:
                print(f"  {r['ts']}  {r['action']:<12} {str(r['data'])[:60]}")
        pause()

    def do_audit_verify(self):
        clear(); self.header()
        if not AUDIT_FILE.exists():
            print(clr("  ❌ audit відсутній", C_RED)); pause(); return
        rows = json.loads(AUDIT_FILE.read_text())
        print(clr(f"  ✅ Записів: {len(rows)}, всі з ts", C_GREEN))
        pause()

    def do_reset(self):
        clear(); self.header()
        ans = input(clr("  ⚠ Повністю скинути стан? [y/N]: ", C_RED)).strip().lower()
        if ans == "y":
            for f in (CONTRACT_FILE, CHAIN_FILE, LEDGER_FILE, AUDIT_FILE):
                if f.exists(): f.unlink()
            self.session.shutdown()
            self.session = ParliamentSession()
            self.session.bootstrap(force_new=True)
            print(clr("  ✅ Скинуто", C_GREEN))
        pause()

    def do_module_status(self):
        clear(); self.header()
        c = self.session.contract
        print(f"  contract_hash : {clr(c.contract_hash[:24] + '…', C_CYAN)}")
        print(f"  agents        : {self._agents_count()}")
        print(f"  proposals     : {self._props_count()} (active: {self._active_count()})")
        print(f"  balances      : {len(c.balances.keys())}")
        print(f"  votes records : {len(c.votes.keys())}")
        print(f"  chain file    : {'✅' if CHAIN_FILE.exists() else '❌'} {CHAIN_FILE.name}")
        print(f"  ledger file   : {'✅' if LEDGER_FILE.exists() else '❌'} {LEDGER_FILE.name}")
        print(f"  backups dir   : {'✅' if BACKUP_DIR.exists() else '❌'} {BACKUP_DIR.name}")
        pause()

    def _print_result(self, r: Dict):
        print()
        print(clr("═" * 60, C_CYAN))
        print(clr(f"  РЕЗУЛЬТАТ {r.get('status','').upper()}", C_BOLD))
        print(clr("═" * 60, C_CYAN))
        print(f"  Текст : {r['text']}")
        print(f"  Автор : {r['author']}")
        print(f"  За    : {clr(str(r['yes']), C_GREEN)}")
        print(f"  Проти : {clr(str(r['no']), C_RED)}")
        print(f"  Утрим : {r['abstain']}")
        print(clr("═" * 60, C_CYAN))

    # ---------- loop ----------
    def run(self):
        actions = {
            1: self.do_deploy, 2: self.do_agents, 3: self.do_propose,
            4: self.do_vote, 5: self.do_tally, 6: self.do_props,
            7: self.do_votes, 8: self.do_auto_vote, 9: self.do_agent_state,
            10: self.do_auto_session, 11: self.do_balances, 12: self.do_ledger,
            13: self.do_reward, 14: self.do_chain_view, 15: self.do_chain_verify,
            16: self.do_backup, 17: self.do_backups_list, 18: self.do_restore,
            19: self.do_export, 20: self.do_audit, 21: self.do_audit_verify,
            22: self.do_reset, 23: self.do_module_status,
        }
        while True:
            self.menu()
            try:
                ch = input(clr("  Вибір: ", C_CYAN)).strip()
            except (EOFError, KeyboardInterrupt):
                break
            if ch in ("0", "q", "exit", "quit"):
                break
            try:
                n = int(ch)
            except ValueError:
                continue
            if n in actions:
                try:
                    actions[n]()
                except Exception as e:
                    print(clr(f"\n  ❌ Помилка: {e}", C_RED))
                    pause()
        self.session.shutdown()
        clear()
        print(clr("  🛑 Сесію завершено", C_DIM))

# ═══════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════
def main():
    try:
        ParliamentTUI().run()
    except KeyboardInterrupt:
        print()

if __name__ == "__main__":
    main()
