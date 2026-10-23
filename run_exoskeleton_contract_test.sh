#!/data/data/com.termux/files/usr/bin/bash
set +e

cd "$HOME/CYBRA" || exit 1

echo "=============================================="
echo " CYBRA EXOSKELETON AI PARLIAMENT"
echo "=============================================="

echo
echo "=== BUILD ==="
forge build

BUILD_RC=$?

if [ "$BUILD_RC" -ne 0 ]; then
    echo "BUILD=FAIL"
    exit "$BUILD_RC"
fi

echo
echo "=== TEST ==="
forge test \
  --match-contract CYBRAExoskeletonAIParliamentTest \
  -vv

TEST_RC=$?

if [ "$TEST_RC" -ne 0 ]; then
    echo "TESTNET_GATE=FAIL"
    exit "$TEST_RC"
fi

echo
echo "=============================================="
echo " TESTNET CONTRACT VERIFICATION: PASS"
echo " ============================================="
echo " LIVE_GATE: LOCKED UNTIL ONCHAIN TRUE100"
echo " MAINNET_GATE: LOCKED"
echo "=============================================="
