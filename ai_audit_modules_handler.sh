#!/data/data/com.termux/files/usr/bin/bash
set -u
cd "$HOME/CYBRA"
mkdir -p state/audit
OUT=$(bash modules/module_19_contract_tui_menu/bin/cybra_ai_executor.sh scan 2>&1)
RC=$?
printf '%s' "$OUT" > state/audit/modules.txt
python3 - "$RC" "$OUT" <<'PY'
import sys, json
rc = int(sys.argv[1])
out = sys.argv[2] if len(sys.argv) > 2 else ""
print(json.dumps({
    "ok": rc == 0,
    "rc": rc,
    "report": "state/audit/modules.txt",
    "lines": len(out.splitlines()),
    "tail": "\n".join(out.splitlines()[-20:]),
}, ensure_ascii=False))
PY
exit $RC
