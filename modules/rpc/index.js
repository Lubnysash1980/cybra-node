const { ethers } = require('ethers');
const BSC_CHAIN_ID = 56;
module.exports = {
  _provider: null, _currentUrl: null,
  async getProvider() {
    if (this._provider) {
      try { await this._provider.getBlockNumber(); return this._provider; }
      catch (e) { this._provider = null; }
    }
    const urls = [process.env.BSC_RPC_URL, 'https://bsc-rpc.publicnode.com', 'https://binance.llamarpc.com', 'https://rpc.ankr.com/bsc'].filter(Boolean);
    for (const url of urls) {
      try {
        console.log(`[rpc] 🔌 ${url.substring(0,45)}...`);
        const p = new ethers.JsonRpcProvider(url, undefined, { staticNetwork: true, batchMaxCount: 1 });
        await Promise.race([p.getNetwork(), new Promise((_,r) => setTimeout(() => r(new Error('timeout')), 8000))]);
        console.log(`[rpc] ✅ ${url}`);
        this._provider = p; this._currentUrl = url;
        return p;
      } catch (err) { console.log(`[rpc] ❌ ${url.substring(0,30)}`); }
    }
    throw new Error('[rpc] Жоден RPC не відповідає.');
  },
  reset() { this._provider = null; this._currentUrl = null; },
  getCurrentUrl() { return this._currentUrl; }
};
