const { ethers } = require('ethers');

const ALLOWED_CONTRACTS = [
  '0x46a15b0b27311cedf172ab29e4f4766fbe7f4364', // NFPM_V3
  '0x0bfbcf9fa4f9c56b0f40a671ad40e0805a091865', // Factory V3
  '0x10ed43c718714eb63d5aa57b78b54704e256024e', // Router V2
];
const MAX_ALLOWED_APPROVE = ethers.parseUnits('1000000', 18);

module.exports = {
  inspect(tx) {
    const to = (tx.to || '').toLowerCase();
    const data = tx.data || '0x';
    const value = tx.value ? BigInt(tx.value) : 0n;

    if (value > 0n && !ALLOWED_CONTRACTS.includes(to)) {
      throw new Error(`SECURITY: Спроба відправити BNB на невідому адресу ${to}`);
    }

    if (data.startsWith('0x095ea7b3')) {
      const iface = new ethers.Interface(['function approve(address,uint256)']);
      const [spender, amount] = iface.decodeFunctionData('approve', data);
      if (!ALLOWED_CONTRACTS.includes(spender.toLowerCase())) {
        throw new Error(`SECURITY: Спроба Approve для невідомого контракту ${spender}`);
      }
      if (amount > MAX_ALLOWED_APPROVE || amount === ethers.MaxUint256) {
        throw new Error(`SECURITY: Заблоковано Approve на суму ${amount.toString()}`);
      }
      console.log(`[security] 🛡️ Approve OK: ${ethers.formatUnits(amount, 18)} токенів`);
      return true;
    }

    if (!ALLOWED_CONTRACTS.includes(to)) {
      throw new Error(`SECURITY: Спроба викликати невідомий контракт ${to}`);
    }
    console.log(`[security] 🛡️ Транзакція до PancakeSwap дозволена`);
    return true;
  }
};
