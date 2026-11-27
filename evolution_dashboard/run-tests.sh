#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
python -m unittest discover -s evolution_dashboard/tests -p 'test_*.py' -v
