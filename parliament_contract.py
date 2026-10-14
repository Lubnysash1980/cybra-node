#!/usr/bin/env python3
# parliament_contract.py – Автономний смарт-контракт AI-парламенту CYBRA
# Мапінг: agents, votes, proposals, balances. Запис результатів у chain.json.

import os
import sys
import json
import time
import hashlib
import random
import threading
import argparse
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Optional, Any, Tuple

# ═══════════════════════════════════════════════════════════════
# КОНФІГУРАЦІЯ
# ═══════════════════════════════════════════════════════════════
BASE_DIR        = Path(__file__).parent
CHAIN_FILE      = BASE_DIR / "chain.json"
CONTRACT_FILE   = BASE_DIR / "parliament.json"
LOG_FILE        = BASE_DIR / "parliament.log"

NUM_AGENTS      = 7
QUORUM          = 4
VOTE_REWARD     = 0.01       # CYB за голос
PROPOSE_REWARD  = 0.10       # CYB автору пропозиції, якщо прийнято
DEFAULT_DEADLINE = 60        # секунд

FACTIONS = [
    "Progressive", "Conservative", "Libertarian",
    "Green", "Technocratic", "Populist", "Independent"
]

# ═══════════════════════════════════════════════════════════════
# УТИЛІТИ
# ═══════════════════════════════════════════════════════════════
def double_sha256(data: bytes) -> str:
    return hashlib.sha256(hashlib.sha256(data).digest()).hexdigest()

def now_iso() -> str:
    return datetime.utcnow().isoformat() + "Z"

def log(msg: str):
    line = f"[{now_iso()}] {msg}"
    print(line, flush=True)
    try:
        with open(LOG_FILE, "a", encoding="utf-8") as f:
            f.write(line + "\n")
    except Exception:
        pass

# ═══════════════════════════════════════════════════════════════
# MAPPING — Solidity-style
# ═══════════════════════════════════════════════════════════════
class Mapping:
    """mapping(address => value) — імітація Solidity-мапінгу."""
    def __init__(self, name: str):
        self.name = name
        self._store: Dict[str, Any] = {}

    def set(self, key: str, value: Any):
        self._store[key] = value

    def get(self, key: str, default=None) -> Any:
        return self._store.get(key, default)

    def has(self, key: str) -> bool:
        return key in self._store

    def delete(self, key: str):
        self._store.pop(key, None)

    def keys(self) -> List[str]:
        return list(self._store.keys())

    def to_dict(self) -> Dict[str, Any]:
        return dict(self._store)

    def load_dict(self, data: Dict[str, Any]):
        self._store = dict(data or {})

# ═══════════════════════════════════════════════════════════════
# СМАРТ-КОНТРАКТ ПАРЛАМЕНТУ
# ═══════════════════════════════════════════════════════════════
class ParliamentContract:
    """
    Автономний смарт-контракт. Мапінги:
      agents     : agent_id   -> {faction, address, weight, created}
      votes      : proposal_id -> {agent_id: choice}
      proposals  : proposal_id -> {text, status, yes, no, abstain, deadline, author}
      balances   : address     -> CYB
    """
    def __init__(self):
        self.agents    = Mapping("agents")
        self.votes     = Mapping("votes")
        self.proposals = Mapping("proposals")
        self.balances  = Mapping("balances")
        self._lock     = threading.RLock()
        self.contract_hash = ""

    # ---------- DEPLOY ----------
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

    # ---------- HASH ----------
    def _compute_hash(self) -> str:
        payload = json.dumps({
            "agents":    self.agents.to_dict(),
            "votes":     self.votes.to_dict(),
            "proposals": self.proposals.to_dict(),
            "balances":  self.balances.to_dict(),
        }, sort_keys=True).encode()
        return double_sha256(payload)

    # ---------- PROPOSE ----------
    def propose(self, text: str, author_agent_id: str, deadline_seconds: int = DEFAULT_DEADLINE) -> Optional[str]:
        if not text.strip():
            log("❌ Порожня пропозиція")
            return None
        author = self.agents.get(author_agent_id)
        if not author:
            log(f"❌ Невідомий автор: {author_agent_id}")
            return None

        proposal_id = double_sha256(f"{text}{author_agent_id}{time.time()}".encode())[:12]
        with self._lock:
            self.proposals.set(proposal_id, {
                "text":     text.strip(),
                "author":   author_agent_id,
                "status":   "voting",
                "created":  now_iso(),
                "deadline": time.time() + deadline_seconds,
                "yes":      0,
                "no":       0,
                "abstain":  0
            })
        log(f"📢 Пропозиція {proposal_id}: {text[:60]}")
        return proposal_id

    # ---------- VOTE ----------
    def vote(self, agent_id: str, proposal_id: str, choice: int) -> bool:
        """choice: 1 = за, -1 = проти, 0 = утримався"""
        if choice not in (-1, 0, 1):
            log(f"❌ Некоректний голос: {choice}")
            return False

        agent    = self.agents.get(agent_id)
        proposal = self.proposals.get(proposal_id)

        if not agent or not proposal:
            log("❌ Немає агента або пропозиції")
            return False
        if proposal["status"] != "voting":
            log(f"❌ Пропозиція {proposal_id} закрита")
            return False
        if time.time() > proposal["deadline"]:
            log(f"❌ Пропозиція {proposal_id} протермінована")
            return False

        with self._lock:
            votes = self.votes.get(proposal_id, {})
            if agent_id in votes:
                log(f"⚠️ {agent_id} вже голосував")
                return False

            votes[agent_id] = choice
            self.votes.set(proposal_id, votes)

            w = agent["weight"]
            if choice == 1:
                proposal["yes"] += w
            elif choice == -1:
                proposal["no"] += w
            else:
                proposal["abstain"] += w
            self.proposals.set(proposal_id, proposal)

            addr = agent["address"]
            self.balances.set(addr, self.balances.get(addr, 0.0) + VOTE_REWARD)

        log(f"🗳️ {agent_id} ({agent['faction']}, w={agent['weight']}) → {choice} на {proposal_id}")
        return True

    # ---------- TALLY ----------
    def tally(self, proposal_id: str) -> Optional[Dict]:
        proposal = self.proposals.get(proposal_id)
        if not proposal:
            return None
        if proposal["status"] != "voting":
            return proposal

        yes, no, abstain = proposal["yes"], proposal["no"], proposal["abstain"]
        total = yes + no + abstain

        if total < QUORUM:
            proposal["status"] = "rejected_quorum"
        elif yes > no:
            proposal["status"] = "passed"
        elif no > yes:
            proposal["status"] = "rejected"
        else:
            proposal["status"] = "tie"

        proposal["tallied_at"] = now_iso()
        with self._lock:
            self.proposals.set(proposal_id, proposal)

            # Нагорода автору, якщо прийнято
            if proposal["status"] == "passed":
                author = self.agents.get(proposal["author"])
                if author:
                    addr = author["address"]
                    self.balances.set(addr, self.balances.get(addr, 0.0) + PROPOSE_REWARD)

        log(f"📊 Tally {proposal_id}: yes={yes} no={no} abstain={abstain} → {proposal['status']}")
        return proposal

    # ---------- SNAPSHOT / SAVE / LOAD ----------
    def snapshot(self) -> Dict:
        return {
            "contract_hash": self._compute_hash(),
            "agents":        self.agents.to_dict(),
            "votes":         self.votes.to_dict(),
            "proposals":     self.proposals.to_dict(),
            "balances":      self.balances.to_dict(),
            "saved_at":      now_iso()
        }

    def save(self, path: Path = CONTRACT_FILE):
        with self._lock:
            data = self.snapshot()
        with open(path, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
        log(f"💾 Стан збережено: {path}")

    def load(self, path: Path = CONTRACT_FILE) -> bool:
        if not path.exists():
            return False
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        self.agents.load_dict(data.get("agents", {}))
        self.votes.load_dict(data.get("votes", {}))
        self.proposals.load_dict(data.get("proposals", {}))
        self.balances.load_dict(data.get("balances", {}))
        self.contract_hash = data.get("contract_hash", "")
        log(f"📂 Стан завантажено з {path}")
        return True

# ═══════════════════════════════════════════════════════════════
# ЗАПИС У БЛОКЧЕЙН CYBRA (chain.json)
# ═══════════════════════════════════════════════════════════════
def append_to_chain(contract: ParliamentContract, proposal_id: str, result: Dict) -> str:
    if CHAIN_FILE.exists():
        try:
            with open(CHAIN_FILE, encoding="utf-8") as f:
                chain = json.load(f)
        except Exception:
            chain = []
    else:
        chain = []

    if not chain:
        chain = [{
            "index": 0, "prev_hash": "0"*64, "task": "Genesis",
            "layers": json.dumps({"logic":"","analysis":"","search":""}),
            "result": "", "nonce": 0, "quality": 100,
            "miner": "genesis", "public_key": "", "signature": "",
            "timestamp": time.time(), "difficulty": 2,
            "hash": "0"*64,
            "metadata": {"version":"1.0","symbol":"CYB","network":"devnet","uuid":"genesis"},
            "transactions": []
        }]

    prev  = chain[-1]
    index = prev["index"] + 1

    task   = f"Parliament vote: {result.get('text','')[:60]}"
    layers = json.dumps({
        "logic":    f"proposal={proposal_id}",
        "analysis": f"yes={result.get('yes')}, no={result.get('no')}, abstain={result.get('abstain')}",
        "search":   f"status={result.get('status')}"
    })

    nonce      = 0
    difficulty = 2
    target     = "0" * difficulty
    timestamp  = time.time()

    while True:
        block_data = f"{index}{prev['hash']}{task}{layers}{result.get('status')}{nonce}{timestamp}"
        block_hash = hashlib.sha256(block_data.encode()).hexdigest()
        if block_hash.startswith(target):
            break
        nonce += 1

    block = {
        "index":     index,
        "prev_hash": prev["hash"],
        "task":      task,
        "layers":    layers,
        "result":    json.dumps(result, ensure_ascii=False),
        "nonce":     nonce,
        "quality":   100,
        "miner":     "parliament_ai",
        "public_key": "",
        "signature":  contract.contract_hash[:32] if contract.contract_hash else "",
        "timestamp":  timestamp,
        "difficulty": difficulty,
        "hash":       block_hash,
        "metadata":   {
            "version": "1.0", "symbol": "CYB",
            "network": "devnet",
            "uuid":    double_sha256(f"{proposal_id}{timestamp}".encode())[:16]
        },
        "transactions": []
    }
    chain.append(block)

    with open(CHAIN_FILE, "w", encoding="utf-8") as f:
        json.dump(chain, f, indent=2, ensure_ascii=False)

    log(f"⛓️ Блок додано: {block_hash[:16]}… (index={index})")
    return block_hash

# ═══════════════════════════════════════════════════════════════
# AI-АГЕНТИ
# ═══════════════════════════════════════════════════════════════
class AIAgent(threading.Thread):
    """Автономний AI-агент зі своєю стратегією голосування."""

    STRATEGIES = {
        "Progressive":  "progressive",
        "Conservative": "conservative",
        "Libertarian":  "libertarian",
        "Green":        "green",
        "Technocratic": "technocratic",
        "Populist":     "populist",
        "Independent":  "random"
    }

    def __init__(self, agent_id: str, contract: ParliamentContract, interval: float = 3.0):
        super().__init__(daemon=True)
        self.agent_id = agent_id
        self.contract = contract
        self.interval = interval
        self.running  = True

    def _decide(self, text: str) -> int:
        agent   = self.contract.agents.get(self.agent_id)
        faction = agent["faction"]
        strat   = self.STRATEGIES.get(faction, "random")
        t       = text.lower()

        if strat == "progressive":
            return 1 if any(k in t for k in ("innovation", "ai", "reform", "future")) else -1
        if strat == "conservative":
            return -1 if any(k in t for k in ("change", "reform", "ban")) else 1
        if strat == "libertarian":
            return -1 if any(k in t for k in ("tax", "ban", "restrict")) else 1
        if strat == "green":
            return 1 if any(k in t for k in ("climate", "green", "eco")) else 0
        if strat == "technocratic":
            return 1 if any(k in t for k in ("data", "algorithm", "ai", "system")) else 0
        if strat == "populist":
            return 1 if any(k in t for k in ("people", "public", "freedom")) else -1
        # random
        return random.choices([1, -1, 0], weights=[5, 3, 2])[0]

    def run(self):
        while self.running:
            # Отримуємо відкриті пропозиції
            open_props = [
                pid for pid, p in self.contract.proposals.to_dict().items()
                if p.get("status") == "voting" and time.time() < p.get("deadline", 0)
            ]
            for pid in open_props:
                votes = self.contract.votes.get(pid, {})
                if self.agent_id in votes:
                    continue
                proposal = self.contract.proposals.get(pid)
                if not proposal:
                    continue
                choice = self._decide(proposal["text"])
                self.contract.vote(self.agent_id, pid, choice)
            time.sleep(self.interval)

    def stop(self):
        self.running = False

# ═══════════════════════════════════════════════════════════════
# МЕНЕДЖЕР СЕСІЇ
# ═══════════════════════════════════════════════════════════════
class ParliamentSession:
    def __init__(self):
        self.contract = ParliamentContract()
        self.agents: List[AIAgent] = []

    def bootstrap(self):
        if not self.contract.load():
            self.contract.deploy(NUM_AGENTS)
            self.contract.save()

        # Створюємо агентів
        for aid in self.contract.agents.keys():
            a = AIAgent(aid, self.contract)
            a.start()
            self.agents.append(a)

        log(f"🧠 Запущено {len(self.agents)} AI-агентів")

    def run_proposal(self, text: str, deadline: int = DEFAULT_DEADLINE):
        author = random.choice(self.contract.agents.keys())
        pid = self.contract.propose(text, author, deadline)
        if not pid:
            return

        log(f"⏳ Голосування триває {deadline} с…")
        t_end = time.time() + deadline
        while time.time() < t_end:
            time.sleep(1)

        result = self.contract.tally(pid)
        if result:
            self.contract.save()
            append_to_chain(self.contract, pid, result)
            self._print_result(pid, result)

    def _print_result(self, pid: str, result: Dict):
        print("\n" + "═" * 60)
        print(f"  РЕЗУЛЬТАТ ПРОПОЗИЦІЇ {pid}")
        print("═" * 60)
        print(f"  Текст:   {result['text']}")
        print(f"  Автор:   {result['author']}")
        print(f"  За:      {result['yes']}")
        print(f"  Проти:   {result['no']}")
        print(f"  Утрим.:  {result['abstain']}")
        print(f"  Статус:  {result['status'].upper()}")
        print("═" * 60 + "\n")

    def shutdown(self):
        for a in self.agents:
            a.stop()
        self.contract.save()
        log("🛑 Сесію завершено")

# ═══════════════════════════════════════════════════════════════
# CLI
# ═══════════════════════════════════════════════════════════════
PROPOSALS = [
    "Прийняти закон про штучний інтелект",
    "Підвищити податок на великі технологічні компанії",
    "Заборонити автономні системи без нагляду",
    "Запровадити green energy для data-центрів",
    "Дати людям свободу вибору цифрових сервісів",
    "Реформувати систему управління алгоритмами",
    "Public data must be open and free",
]

def main():
    parser = argparse.ArgumentParser(description="AI Parliament Smart Contract (CYBRA)")
    parser.add_argument("--propose", type=str,  help="Текст пропозиції")
    parser.add_argument("--deadline", type=int, default=DEFAULT_DEADLINE)
    parser.add_argument("--auto", action="store_true", help="Автогенерація пропозицій")
    parser.add_argument("--count", type=int, default=3, help="Скільки пропозицій у --auto")
    parser.add_argument("--list", action="store_true", help="Показати стан парламенту")
    args = parser.parse_args()

    session = ParliamentSession()
    session.bootstrap()

    try:
        if args.list:
            print("\n📋 Стан парламенту:")
            for pid, p in session.contract.proposals.to_dict().items():
                print(f"  {pid}: {p['text'][:50]} → {p['status']}")
            return

        if args.propose:
            session.run_proposal(args.propose, args.deadline)
        elif args.auto:
            for i in range(args.count):
                text = random.choice(PROPOSALS)
                print(f"\n▶ Пропозиція {i+1}/{args.count}")
                session.run_proposal(text, args.deadline)
        else:
            # Інтерактивний режим
            print("\n💬 Введи текст пропозиції (або Enter для випадкової). 'exit' — вихід.")
            while True:
                text = input("\nПропозиція → ").strip()
                if text.lower() in ("exit", "quit", "q"):
                    break
                if not text:
                    text = random.choice(PROPOSALS)
                    print(f"  (обрано): {text}")
                session.run_proposal(text, args.deadline)
    finally:
        session.shutdown()

if __name__ == "__main__":
    main()

