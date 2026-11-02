#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail
ROOT="${CYBRA_PROVISIONER_ROOT:-$HOME/CYBRA/provisioner}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "$ROOT/state" "$ROOT/work"
cp -a "$HERE"/*.js "$HERE"/*.sh "$ROOT/"
chmod +x "$ROOT"/*.js "$ROOT"/*.sh
for f in "$ROOT"/*.js; do node --check "$f"; done
bash -n "$ROOT/05-node-bootstrap.sh"
echo '[OK] CYBRA Node Provisioner installed'
echo 'Required environment:'
echo '  export GITHUB_APP_ID=...'
echo '  export GITHUB_APP_PRIVATE_KEY=/path/to/app-private-key.pem'
echo 'Run:'
echo '  node 01-github-auth.js INSTALLATION_ID OWNER/REPO'
echo '  node 02-node-provisioner.js'
echo '  node 03-snapshot-builder.js'
echo '  node 04-repo-deployer.js'
echo '  node 06-node-link.js'
