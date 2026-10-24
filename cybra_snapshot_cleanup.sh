#!/data/data/com.termux/files/usr/bin/bash
# залишити найстаріший снапшот з однаковими метаданими
set -u
SNAPS="$HOME/CYBRA/snapshots"
cd "$SNAPS" || exit 1

declare -A seen
for f in $(ls -1tr parliament_*.tar.gz 2>/dev/null); do
  work=$(mktemp -d)
  tar -xzf "$f" -C "$work" 2>/dev/null
  meta=$(find "$work" -name metadata.json 2>/dev/null | head -1)
  if [ -n "$meta" ]; then
    sig=$(python3 -c "import json;d=json.load(open('$meta'));print(f\"{d['level']}-{d['results']}-{d['modules_count']}-{d['queue']}\")" 2>/dev/null)
    if [ -n "${seen[$sig]:-}" ]; then
      echo "🗑 дубль: $f (== ${seen[$sig]})"
      rm -f "$f"
    else
      seen[$sig]="$f"
      echo "✓ keep: $f  [$sig]"
    fi
  fi
  rm -rf "$work"
done
