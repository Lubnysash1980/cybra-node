#!/usr/bin/env bash
set -uo pipefail
ROOT="${CYBRA_ROOT:-$HOME/CYBRA}"
cd "$ROOT"
echo "=== CYBRA DEPENDENCY DIAGNOSTICS (READ ONLY) ==="
echo "ROOT=$ROOT"
if ! command -v npm >/dev/null 2>&1; then
  echo "NPM=NOT_INSTALLED"
  exit 0
fi
echo "NPM_VERSION=$(npm --version)"
if [[ -f package.json ]]; then
  echo "PACKAGE_JSON=FOUND"
  npm ls --all --json > /tmp/cybra-npm-tree-$$.json 2>/tmp/cybra-npm-tree-$$.err
  rc=$?
  python3 - "$$" <<'PY'
import json,sys
from pathlib import Path
pid=sys.argv[1]
p=Path(f"/tmp/cybra-npm-tree-{pid}.json")
try:
    data=json.loads(p.read_text())
except Exception as e:
    print("TREE_PARSE_ERROR",e)
    raise SystemExit(0)
problems=[]
def walk(node,where="root"):
    for name,item in (node.get("dependencies") or {}).items():
        if item.get("missing") or item.get("invalid") or item.get("problems"):
            problems.append({"name":name,"path":where,"version":item.get("version"),"missing":item.get("missing"),"invalid":item.get("invalid"),"problems":item.get("problems")})
        walk(item,where+"/"+name)
walk(data)
print("DEPENDENCY_PROBLEMS="+str(len(problems)))
for x in problems[:100]: print(json.dumps(x,ensure_ascii=False))
PY
  if [[ "$rc" -eq 0 ]]; then echo "NPM_TREE=OK"; else echo "NPM_TREE=NONZERO_EXIT_$rc (inspect diagnostics above)"; fi
  rm -f "/tmp/cybra-npm-tree-$$.json" "/tmp/cybra-npm-tree-$$.err"
else
  echo "PACKAGE_JSON=NOT_FOUND"
fi
if [[ -f package-lock.json ]]; then echo "PACKAGE_LOCK=FOUND"; else echo "PACKAGE_LOCK=NOT_FOUND"; fi
echo "NOTE: no install, uninstall, dedupe, cache clean, or lockfile mutation was performed."
