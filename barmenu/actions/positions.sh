#!/data/data/com.termux/files/usr/bin/bash
. barmenu/lib/colors.sh
clear
title "═══ МОЇ NFT-ПОЗИЦІЇ ═══"
node -e "
require('dotenv').config();
const { ethers } = require('ethers');
(async () => {
  const p = new ethers.JsonRpcProvider(process.env.BSC_RPC_URL);
  const wallet = '0x9f6b6054d74052c98142a4c3797a078eddd48c58';
  const nfpm = new ethers.Contract('0x46A15B0b27311cedF172AB29E4f4766fbE7F4364', [
    'function balanceOf(address) view returns (uint256)',
    'function tokenOfOwnerByIndex(address,uint256) view returns (uint256)',
    'function positions(uint256) view returns (uint96 nonce, address operator, address token0, address token1, uint24 fee, int24 tickLower, int24 tickUpper, uint128 liquidity, uint256 feeGrowthInside0LastX128, uint256 feeGrowthInside1LastX128, uint128 tokensOwed0, uint128 tokensOwed1)'
  ], p);

  const bal = await nfpm.balanceOf(wallet);
  console.log('📊 NFT-позицій: ' + bal.toString());
  console.log('');
  for (let i = 0; i < bal; i++) {
    try {
      const tokenId = await nfpm.tokenOfOwnerByIndex(wallet, i);
      const pos = await nfpm.positions(tokenId);
      console.log('🎫 NFT #' + tokenId.toString());
      console.log('   Token0: ' + pos.token0);
      console.log('   Token1: ' + pos.token1);
      console.log('   Fee: ' + pos.fee);
      console.log('   Tick range: [' + pos.tickLower + ', ' + pos.tickUpper + ']');
      console.log('   Liquidity: ' + pos.liquidity.toString());
      console.log('   Fees owed0: ' + ethers.formatUnits(pos.tokensOwed0, 18));
      console.log('   Fees owed1: ' + ethers.formatUnits(pos.tokensOwed1, 18));
      console.log('');
    } catch(e) { console.log('   ⚠️ Не вдалося прочитати #' + i); }
  }
})();
"
