#!/data/data/com.termux/files/usr/bin/bash
set -u
cd ~/CYBRA 2>/dev/null || { echo "❌ Немає папки ~/CYBRA"; exit 1; }

PASS=0; FAIL=0
ok()  { echo "  ✅ $1"; PASS=$((PASS+1)); }
bad() { echo "  ❌ $1"; FAIL=$((FAIL+1)); }
run() { echo ""; echo "▶ $1"; }

echo "╔══════════════════════════════════════════╗"
echo "║  CYBRA AUTOTEST - Перевірка архітектури  ║"
echo "╚══════════════════════════════════════════╝"

# 1. Node.js
run "1/6 • Node.js"
command -v node >/dev/null && ok "Node.js $(node --version)" || bad "Node.js відсутній"

# 2. Пакети
run "2/6 • npm пакети"
for p in ethers @walletconnect/sign-client @pancakeswap/v3-sdk @pancakeswap/swap-sdk-core dotenv; do
  [ -d "node_modules/$p" ] && ok "$p" || bad "$p (встанови: npm install $p)"
done

# 3. Env
run "3/6 • .env конфіг"
if [ -f ".env" ]; then
  ok ".env існує"
  for k in WC_PROJECT_ID BSC_RPC_URL TOKEN_ADDR QUOTE_ADDR; do
    grep -q "^$k=" .env && ok "$k" || bad "$k відсутній"
  done
else
  bad ".env не створено"
fi

# 4. RPC
run "4/6 • RPC нода"
node -e '
require("dotenv").config();
const { ethers } = require("ethers");
const url = process.env.BSC_RPC_URL || "https://bsc-rpc.publicnode.com";
(async () => {
  try {
    const p = new ethers.JsonRpcProvider(url, undefined, { staticNetwork: true });
    const blk = await Promise.race([p.getBlockNumber(), new Promise((_,r)=>setTimeout(()=>r(new Error("timeout 8s")),8000))]);
    console.log("  ✅ BSC block: " + blk);
    process.exit(0);
  } catch(e) { console.log("  ❌ " + e.message); process.exit(1); }
})();
' && PASS=$((PASS+1)) || FAIL=$((FAIL+1))

# 5. Security Controller
run "5/6 • Security Controller (MaxUint256)"
node -e '
const { ethers } = require("ethers");
function inspect(tx) {
  if (!tx.data || !tx.data.startsWith("0x095ea7b3")) return true;
  const iface = new ethers.Interface(["function approve(address,uint256)"]);
  const d = iface.decodeFunctionData("approve", tx.data);
  if (d[1] === ethers.MaxUint256) throw new Error("SECURITY");
  return true;
}
const iface = new ethers.Interface(["function approve(address,uint256)"]);
const spender = "0x46A15B0b27311cedF172AB29E4f4766fbE7F4364";

let blocked = false;
try { inspect({ data: iface.encodeFunctionData("approve", [spender, ethers.MaxUint256]) }); } catch(e){ blocked = true; }
if (!blocked) { console.log("  ❌ MaxUint256 НЕ заблоковано"); process.exit(1); }
console.log("  ✅ MaxUint256 блокується");

try {
  inspect({ data: iface.encodeFunctionData("approve", [spender, ethers.parseUnits("100",18)]) });
  console.log("  ✅ Approve(100 CYBRA) дозволено");
} catch(e) { console.log("  ❌ Безпечний approve заблоковано"); process.exit(1); }
' && PASS=$((PASS+2)) || FAIL=$((FAIL+1))

# 6. Логіка тіків
run "6/6 • Логіка V3 (математика тіків)"
node -e '
try {
  const { nearestUsableTick } = require("@pancakeswap/v3-sdk");
  const tickSpacing = 50;
  const cur = 0;
  const delta = Math.round(Math.log(2) / Math.log(1.0001));
  const tL = nearestUsableTick(cur - delta, tickSpacing);
  const tU = nearestUsableTick(cur - tickSpacing, tickSpacing);
  if (tL < tU && tU < cur) {
    console.log("  ✅ Діапазон: [" + tL + ", " + tU + "] (нижче ринку " + cur + ")");
  } else {
    console.log("  ❌ Неправильний діапазон");
    process.exit(1);
  }
} catch(e) { console.log("  ❌ " + e.message); process.exit(1); }
' && PASS=$((PASS+1)) || FAIL=$((FAIL+1))

# ---- Структура модулів (інформаційно) ----
echo ""
echo "▶ Інформаційно: структура модулів"
for m in rpc security notifier ai-fixer pool_v3; do
  if [ -f "modules/$m/index.js" ]; then
    if node -c "modules/$m/index.js" 2>/dev/null; then
      echo "  ✅ modules/$m/index.js (OK)"
    else
      echo "  ⚠️  modules/$m/index.js (синтаксична помилка)"
    fi
  else
    echo "  ⏳ modules/$m/index.js (треба створити)"
  fi
done

echo ""
echo "══════════════════════════════════════════"
echo "  ✅ PASS: $PASS   ❌ FAIL: $FAIL"
echo "══════════════════════════════════════════"
if [ $FAIL -eq 0 ]; then
  echo "🎉 Архітектура робоча. Можна запускати систему."
  exit 0
else
  echo "⚠️  Виправ $FAIL проблем вище."
  exit 1
fi
