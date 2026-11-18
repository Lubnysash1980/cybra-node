GREEN='\033[1;32m'; YELLOW='\033[1;33m'; RED='\033[1;31m'; BLUE='\033[1;34m'; CYAN='\033[1;36m'; NC='\033[0m'
ok()   { echo -e "${GREEN}● GREEN${NC}  $*"; }
warn() { echo -e "${YELLOW}● YELLOW${NC} $*"; }
err()  { echo -e "${RED}● RED${NC}    $*"; }
info() { echo -e "${BLUE}ℹ${NC}  $*"; }
title(){ echo -e "${CYAN}$*${NC}"; }
