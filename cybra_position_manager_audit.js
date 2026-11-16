'use strict';

require('dotenv').config();
const { ethers } = require('ethers');

const RPC = process.env.BSC_RPC_URL ||
  'https://bsc-rpc.publicnode.com';

const TOKEN = ethers.getAddress(process.env.TOKEN_ADDR);
const QUOTE = ethers.getAddress(process.env.QUOTE_ADDR);

const FACTORY = ethers.getAddress(
  '0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865'
);

const MANAGER = ethers.getAddress(
  '0x46A15B0b27311cedF172AB29E4f4766fbE7F4364'
);

const WBNB = ethers.getAddress(
  '0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c'
);

const FEE = 2500;

const MANAGER_ABI = [
  'function factory() view returns(address)',
  'function WETH9() view returns(address)',
  'function supportsInterface(bytes4) view returns(bool)'
];

const FACTORY_ABI = [
  'function getPool(address,address,uint24) view returns(address)'
];

const POOL_ABI = [
  'function factory() view returns(address)',
  'function token0() view returns(address)',
  'function token1() view returns(address)',
  'function fee() view returns(uint24)',
  'function tickSpacing() view returns(int24)',
  'function liquidity() view returns(uint128)'
];

async function main() {
  const provider = new ethers.JsonRpcProvider(RPC);

  try {
    console.log('\n===== CYBRA POSITION MANAGER AUDIT =====');
    console.log('READ ONLY — NO TRANSACTIONS\n');

    const network = await provider.getNetwork();
    console.log('Chain ID:', network.chainId.toString());

    if (network.chainId !== 56n) {
      throw new Error('Wrong network. Expected BNB Chain 56.');
    }

    console.log('\n--- MANAGER CONTRACT ---');

    const code = await provider.getCode(MANAGER);
    console.log('Address:', MANAGER);
    console.log('Contract deployed:', code !== '0x');
    console.log('Bytecode length:', (code.length - 2) / 2);

    if (code === '0x') {
      throw new Error('Position Manager has no contract code');
    }

    const manager = new ethers.Contract(
      MANAGER,
      MANAGER_ABI,
      provider
    );

    console.log('\n--- MANAGER READ-ONLY METHODS ---');

    let managerFactory;
    let managerWBNB;

    try {
      managerFactory = await manager.factory();
      console.log('Manager factory:', managerFactory);
      console.log(
        'Factory matches official:',
        managerFactory.toLowerCase() === FACTORY.toLowerCase()
      );
    } catch (err) {
      console.log('factory() call failed:', err.message);
    }

    try {
      managerWBNB = await manager.WETH9();
      console.log('Manager WETH9:', managerWBNB);
      console.log(
        'WETH9 matches BNB Chain WBNB:',
        managerWBNB.toLowerCase() === WBNB.toLowerCase()
      );
    } catch (err) {
      console.log('WETH9() call failed:', err.message);
    }

    console.log('\n--- ERC721 INTERFACE ---');

    for (const [name, id] of [
      ['ERC721', '0x80ac58cd'],
      ['ERC721Metadata', '0x5b5e139f']
    ]) {
      try {
        const supported = await manager.supportsInterface(id);
        console.log(`${name}:`, supported);
      } catch (err) {
        console.log(`${name}: check failed`);
      }
    }

    console.log('\n--- CYBRA V3 POOL LINK ---');

    const factory = new ethers.Contract(
      FACTORY,
      FACTORY_ABI,
      provider
    );

    const poolAddress = await factory.getPool(
      TOKEN,
      QUOTE,
      FEE
    );

    console.log('Pool:', poolAddress);

    if (poolAddress === ethers.ZeroAddress) {
      console.log('Pool not found.');
      return;
    }

    const pool = new ethers.Contract(
      poolAddress,
      POOL_ABI,
      provider
    );

    const [
      poolFactory,
      token0,
      token1,
      fee,
      spacing,
      liquidity
    ] = await Promise.all([
      pool.factory(),
      pool.token0(),
      pool.token1(),
      pool.fee(),
      pool.tickSpacing(),
      pool.liquidity()
    ]);

    console.log('Pool factory:', poolFactory);
    console.log('Pool token0:', token0);
    console.log('Pool token1:', token1);
    console.log('Pool fee:', fee.toString());
    console.log('Pool tick spacing:', spacing.toString());
    console.log('Pool liquidity:', liquidity.toString());

    console.log('\n--- FINAL CHECKS ---');

    console.log(
      'Manager factory = pool factory:',
      !!managerFactory &&
      managerFactory.toLowerCase() === poolFactory.toLowerCase()
    );

    console.log(
      'Pool belongs to configured factory:',
      poolFactory.toLowerCase() === FACTORY.toLowerCase()
    );

    console.log(
      'Pool token addresses match:',
      [token0.toLowerCase(), token1.toLowerCase()]
        .includes(TOKEN.toLowerCase()) &&
      [token0.toLowerCase(), token1.toLowerCase()]
        .includes(QUOTE.toLowerCase())
    );

    console.log(
      'Fee is 2500:',
      Number(fee) === FEE
    );

    console.log('\n===== AUDIT COMPLETE =====');
    console.log('No transactions sent.');
    console.log('No approvals requested.');
    console.log('No tokens moved.');

  } finally {
    await provider.destroy();
  }
}

main().catch(err => {
  console.error('\nAUDIT ERROR:', err.shortMessage || err.message);
  process.exitCode = 1;
});
