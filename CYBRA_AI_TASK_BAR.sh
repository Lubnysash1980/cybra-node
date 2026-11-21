#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="$HOME/CYBRA"
QUEUE="$ROOT/hash_ecosystem/executors/executor_001/queue"
RESULTS="$ROOT/hash_ecosystem/executors/executor_001/results"
WORK="$ROOT/hash_ecosystem/executors/executor_001/work"
EVIDENCE="$ROOT/hash_ecosystem/executors/executor_001/evidence"
DIALOG="$ROOT/hash_ecosystem/ai_task_dialogue"

ENGINE="$ROOT/CYBRA_EXECUTOR_001_ENGINE_002.sh"

mkdir -p "$QUEUE" "$RESULTS" "$WORK" "$EVIDENCE" "$DIALOG"

sha256() {
    sha256sum "$1" | awk '{print $1}'
}

pause_bar() {
    echo
    read -r -p "ENTER — меню..." _
}

create_task() {
    clear
    echo "============================================================"
    echo " CYBRA AI TASK BAR — NEW TASK"
    echo "============================================================"
    echo

    read -r -p "Питання / завдання: " QUESTION

    if [[ -z "$QUESTION" ]]; then
        echo "FAIL: EMPTY_TASK"
        pause_bar
        return
    fi

    read -r -p "Рівень [1]: " LEVEL
    LEVEL="${LEVEL:-1}"

    read -r -p "Пріоритет [NORMAL]: " PRIORITY
    PRIORITY="${PRIORITY:-NORMAL}"

    TS="$(date -u +%Y%m%dT%H%M%SZ)"
    CREATED="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    TASK_ID="AI-TASK-${TS}-$$"
    TASK="$QUEUE/$TASK_ID.json"

    python3 - "$TASK" "$TASK_ID" "$QUESTION" "$LEVEL" "$PRIORITY" "$CREATED" <<'PY'
import json, sys

path, task_id, question, level, priority, created = sys.argv

task = {
    "task_id": task_id,
    "type": "FACT_RESEARCH",
    "required_role": "RESEARCH_AND_TASK_EXECUTOR",
    "priority": priority,
    "difficulty_level": int(level),
    "status": "PENDING",
    "candidate": True,
    "verified": False,
    "true100": False,
    "evo_required": True,
    "source_of_truth": "HASH_ECOSYSTEM",
    "answer_injected": False,
    "remote_code_execution": False,
    "network_execution": False,
    "objective": question,
    "question": question,
    "required_output": [
        "FACT",
        "EVIDENCE",
        "UNKNOWN",
        "CONFLICT",
        "EVIDENCE_GAP",
        "timestamp",
        "source_refs",
        "sha256"
    ],
    "created_at": created,
    "safety_rules": [
        "Не вигадувати факт",
        "Не перетворювати UNKNOWN на FACT без evidence",
        "VERIFIED тільки після незалежної перевірки",
        "TRUE_100 тільки через EVO",
        "Не виконувати віддалений код"
    ]
}

with open(path, "w", encoding="utf-8") as f:
    json.dump(task, f, ensure_ascii=False, indent=2)
PY

    SHA="$(sha256 "$TASK")"

    echo
    echo "TASK CREATED"
    echo "------------------------------------------------------------"
    echo "TASK ID : $TASK_ID"
    echo "LEVEL   : $LEVEL"
    echo "PRIORITY: $PRIORITY"
    echo "SHA256  : $SHA"
    echo "STATUS  : PENDING"
    echo "------------------------------------------------------------"

    printf '%s\n' "$CREATED | USER | CREATE_TASK | $TASK_ID | $SHA" \
        >> "$DIALOG/$TASK_ID.ndjson"

    echo
    read -r -p "Запустити Executor-001 зараз? [y/N]: " RUN

    if [[ "$RUN" =~ ^[Yy]$ ]]; then
        echo
        echo "=== EXECUTOR-001 ==="
        bash "$ENGINE" "$TASK"

        echo
        echo "=== TASK STATE ==="
        python3 - "$TASK" <<'PY'
import json,sys
with open(sys.argv[1],encoding="utf-8") as f:
    x=json.load(f)
for k in [
    "task_id","type","status",
    "self_check_percent","deviation_percent",
    "verified","true100","evo_required"
]:
    print(f"{k.upper():24}: {x.get(k)}")
PY
    fi

    pause_bar
}

show_tasks() {
    clear
    echo "============================================================"
    echo " CYBRA AI TASK BAR — TASKS"
    echo "============================================================"

    python3 - "$QUEUE" <<'PY'
import glob,json,os

files=sorted(glob.glob(os.path.join(sys.argv[1],"*.json")))[-30:]

if not files:
    print("NO TASKS")
    raise SystemExit

for p in reversed(files):
    try:
        with open(p,encoding="utf-8") as f:
            x=json.load(f)
        print()
        print("TASK      :", x.get("task_id"))
        print("TYPE      :", x.get("type"))
        print("STATUS    :", x.get("status"))
        print("LEVEL     :", x.get("difficulty_level"))
        print("VERIFIED  :", x.get("verified"))
        print("TRUE_100  :", x.get("true100"))
        print("QUESTION  :", x.get("question","")[:100])
except Exception as e:
        print("ERROR:",p,e)
PY

    pause_bar
}

show_task() {
    clear
    echo "============================================================"
    echo " CYBRA AI TASK BAR — TASK DETAIL"
    echo "============================================================"
    echo

    read -r -p "TASK ID: " ID
    TASK="$QUEUE/$ID.json"

    if [[ ! -f "$TASK" ]]; then
        echo "FAIL: TASK_NOT_FOUND"
        pause_bar
        return
    fi

    cat "$TASK"

    echo
    echo "TASK SHA256:"
    sha256 "$TASK"

    pause_bar
}

show_dialogue() {
    clear
    echo "============================================================"
    echo " CYBRA AI TASK BAR — DIALOGUE / EVIDENCE"
    echo "============================================================"
    echo

    read -r -p "TASK ID: " ID
    FILE="$DIALOG/$ID.ndjson"

    if [[ ! -f "$FILE" ]]; then
        echo "NO_DIALOGUE_YET"
        pause_bar
        return
    fi

    echo
    cat "$FILE"

    pause_bar
}

show_run() {
    clear
    echo "============================================================"
    echo " CYBRA AI TASK BAR — EXECUTION"
    echo "============================================================"
    echo

    read -r -p "RUN ID: " RUN

    DIR="$WORK/$RUN"

    if [[ ! -d "$DIR" ]]; then
        echo "FAIL: RUN_NOT_FOUND"
        pause_bar
        return
    fi

    echo
    echo "--- RUN FILES ---"
    find "$DIR" -maxdepth 1 -type f -printf '%f\n' 2>/dev/null | sort

    echo
    echo "--- FINAL GATE ---"
    if [[ -f "$DIR/FINAL_GATE.json" ]]; then
        cat "$DIR/FINAL_GATE.json"
    else
        echo "NOT_FOUND"
    fi

    echo
    echo "--- FACT RESEARCH ---"
    if [[ -f "$DIR/fact_research.json" ]]; then
        cat "$DIR/fact_research.json"
    else
        echo "NOT_FOUND"
    fi

    pause_bar
}

show_latest() {
    clear
    echo "============================================================"
    echo " CYBRA AI TASK BAR — LATEST"
    echo "============================================================"

    python3 - "$QUEUE" "$RESULTS" <<'PY'
import glob,json,os

tasks=glob.glob(os.path.join(sys.argv[1],"*.json"))

if not tasks:
    print("NO TASKS")
    raise SystemExit

tasks.sort(key=os.path.getmtime, reverse=True)
p=tasks[0]

with open(p,encoding="utf-8") as f:
    t=json.load(f)

print()
print("TASK       :",t.get("task_id"))
print("QUESTION   :",t.get("question"))
print("STATUS     :",t.get("status"))
print("SELF CHECK :",t.get("self_check_percent","UNKNOWN"))
print("DEVIATION  :",t.get("deviation_percent","UNKNOWN"))
print("VERIFIED   :",t.get("verified"))
print("TRUE_100   :",t.get("true100"))
print("EVO        :",t.get("evo_required"))
print("LAST RUN   :",t.get("last_run","NONE"))
print()

results=glob.glob(os.path.join(sys.argv[2],"*.json"))

for r in sorted(results,key=os.path.getmtime,reverse=True):
    try:
        with open(r,encoding="utf-8") as f:
            x=json.load(f)
        if x.get("task_id")==t.get("task_id"):
            print("EXECUTOR RESULT")
            print("----------------")
            print("STATE      :",x.get("state"))
            print("VERIFIED   :",x.get("verified"))
            print("TRUE_100   :",x.get("true100"))
            print("READY      :",x.get("ready_for_independent_verification"))
            print("EVO        :",x.get("evo_required"))
            break
    except Exception:
        pass
PY

    pause_bar
}

while true; do
    clear

    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║                 CYBRA AI TASK BAR                         ║"
    echo "╠════════════════════════════════════════════════════════════╣"
    echo "║                                                            ║"
    echo "║  1. НОВЕ AI-ЗАВДАННЯ                                      ║"
    echo "║  2. МОЇ AI-ТУСКИ                                           ║"
    echo "║  3. ОСТАННЄ ЗАВДАННЯ                                      ║"
    echo "║  4. ДЕТАЛІ ЗАВДАННЯ                                       ║"
    echo "║  5. EXECUTION / FINAL GATE                                ║"
    echo "║  6. ДІАЛОГ / EVIDENCE                                     ║"
    echo "║  0. ВИХІД                                                 ║"
    echo "║                                                            ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo

    read -r -p "CYBRA AI > " MENU

    case "$MENU" in
        1) create_task ;;
        2) show_tasks ;;
        3) show_latest ;;
        4) show_task ;;
        5) show_run ;;
        6) show_dialogue ;;
        0) exit 0 ;;
        *) echo "Невірний пункт"; sleep 1 ;;
    esac
done
