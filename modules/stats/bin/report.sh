#!/data/data/com.termux/files/usr/bin/bash
set -u
MOD="$(cd "$(dirname "$0")/.." && pwd)"
STATE="$MOD/state"
CUR="$STATE/current.json"
ANOM="$STATE/anomalies.json"

case "${1:-short}" in
  json)
    if [ -f "$CUR" ]; then
      jq -n --slurpfile c "$CUR" --slurpfile a "$ANOM" '{stats:$c[0], anomalies:($a[0].anomalies // [])}'
    else
      echo '{}'
    fi
    ;;
  short)
    if [ ! -f "$CUR" ]; then echo "unknown"; exit 0; fi
    C=$(jq -r '.anomalies|length // 0' "$ANOM" 2>/dev/null || echo 0)
    T=$(jq -r '.anomalies[]?.type' "$ANOM" 2>/dev/null | tr '\n' ',' | sed 's/,$//')
    if [ "$C" -eq 0 ]; then echo "green 0A"
    else echo "yellow ${C}A [$T]"; fi
    ;;
  full)
    echo "╔════════════ STATS ════════════╗"
    if [ ! -f "$CUR" ]; then echo "║ (no data — run collect.sh)   ║"; echo "╚═══════════════════════════════╝"; exit 0; fi
    WIN=$(jq -r '.window_sec // 3600' "$CUR")
    CUT=$(jq -r '.window_cut // "-"' "$CUR")
    echo "║ window: ${WIN}s (cut=$CUT)"
    echo ""
    echo "── autowatch ──"
    jq -r '.autowatch | to_entries[] | "  \(.key): \(.value)"' "$CUR"
    echo "── bg_dump ──"
    jq -r '.bg_dump | to_entries[] | "  \(.key): \(.value)"' "$CUR"
    echo "── autodopomoga ──"
    jq -r '.autodopomoga | {repair_cycles, after_repairs, by_component} | to_entries[] | "  \(.key): \(.value)"' "$CUR"
    echo "── autogit ──"
    jq -r '.autogit | to_entries[] | "  \(.key): \(.value)"' "$CUR"
    echo "── parliament ──"
    jq -r '.parliament | to_entries[] | "  \(.key): \(.value)"' "$CUR"
    echo "── pm2 ──"
    jq -r '.pm2 | to_entries[] | "  \(.key): \(.value)"' "$CUR"
    echo "── daemons ──"
    jq -r '.daemons | to_entries[] | "  \(.key): \(.value)"' "$CUR"
    echo ""
    echo "── anomalies ──"
    if [ -f "$ANOM" ]; then
      N=$(jq '.anomalies|length // 0' "$ANOM")
      if [ "$N" -eq 0 ]; then
        echo "  ✅ none"
      else
        jq -r '.anomalies[] | "  ⚠ \(.type) [\(.component // "all")] = \(.value)"' "$ANOM"
      fi
    fi
    echo "╚═══════════════════════════════╝"
    ;;
  *) echo "usage: report.sh {short|json|full}"; exit 1 ;;
esac
