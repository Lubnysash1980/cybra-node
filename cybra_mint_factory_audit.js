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

const POSITION_MANAGER = ethers.getAddress(
  '0x46A15B0b27311cedF172AB29E4f4766fbE7F4364'
);

const ROUTER = ethers.getAddress(
  '0x1b81D678ffb9C0263b24A97847620C99d213eB14'
);

const FEE = 2500;

const FACTORY_ABI = [
  'function getPool(address,address,uint24) view returns(address)',
  'function feeAmountTickSpacing(uint24) view returns(int24)'
];

const POOL_ABI = [
  'function factory() view returns(address)',
  'function token0() view returns(address)',
  'function token1() view returns(address)',
  'function fee() view returns(uint24)',
  'function tickSpacing() view returns(int24)',
  'function liquidity() view returns(uint128)',
  'function slot0() view returns(uint160,int24,uint16,uint16,uint16,uint8,bool)'
];

async function codeCheck(provider, name, address) {
  const code = await provider.getCode(address);
  const exists = code !== '0x';

  console.log(`${name}: ${address}`);
  console.log(`  Contract deployed: ${exists ? 'YES' : 'NO'}`);
  console.log(`  Bytecode length: ${(code.length - 2) / 2}`);

  return exists;
}

async function main() {
  console.log('\n===== CYBRA FACTORY AUDIT =====');
  console.log('READ ONLY — NO TRANSACTIONS\n');

  const provider = new ethers.JsonRpcProvider(RPC);

  try {
    const network = await provider.getNetwork();

    console.log('Chain ID:', network.chainId.toString());

    if (network.chainId !== 56n) {
      throw new Error('Wrong network: expected BNB Chain 56');
    }

    console.log('\n--- OFFICIAL CONTRACT ADDRESSES ---');

    const factoryExists =
      await codeCheck(provider, 'Factory', FACTORY);

    const managerExists =
      await codeCheck(
        provider,
        'Position Manager',
        POSITION_MANAGER
      );

    const routerExists =
      await codeCheck(provider, 'V3 Router', ROUTER);

    if (!factoryExists) {
      throw new Error('Factory has no deployed bytecode');
    }

    console.log('\n--- FACTORY CHECK ---');

    const factory = new ethers.Contract(
      FACTORY,
      FACTORY_ABI,
      provider
    );

    const [poolAddress, spacing] = await Promise.all([
      factory.getPool(TOKEN, QUOTE, FEE),
      factory.feeAmountTickSpacing(FEE)
    ]);

    console.log('Fee:', FEE);
    console.log('Tick spacing:', spacing.toString());
    console.log('Pool returned:', poolAddress);

    if (poolAddress === ethers.ZeroAddress) {
      console.log('Pool not found.');
      return;
    }

    console.log('\n--- POOL CHECK ---');

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
      tickSpacing,
      liquidity,
      slot
    ] = await Promise.all([
      pool.factory(),
      pool.token0(),
      pool.token1(),
      pool.fee(),
      pool.tickSpacing(),
      pool.liquidity(),
      pool.slot0()
    ]);

    console.log('Pool factory:', poolFactory);

    console.log(
      'Factory matches:',
      poolFactory.toLowerCase() === FACTORY.toLowerCase()
    );

    console.log('Token0:', token0);
    console.log('Token1:', token1);

    console.log('Fee:', fee.toString());
    console.log('Tick spacing:', tickSpacing.toString());
    console.log('Current tick:', slot[1].toString());
    console.log('Liquidity:', liquidity.toString());

    console.log('\n--- CONSISTENCY CHECK ---');

    console.log(
      'Fee spacing matches:',
      spacing === tickSpacing
    );

    console.log(
      'Fee matches:',
      Number(fee) === FEE
    );

    console.log(
      'Token addresses match:',
      [token0.toLowerCase(), token1.toLowerCase()]
        .includes(TOKEN.toLowerCase()) &&
      [token0.toLowerCase(), token1.toLowerCase()]
        .includes(QUOTE.toLowerCase())
    );

    console.log('\n--- SUMMARY ---');

    if (
      poolFactory.toLowerCase() === FACTORY.toLowerCase() &&
      spacing === tickSpacing &&
      Number(fee) === FEE
    ) {
      console.log('FACTORY/POOL CONSISTENCY: PASS');
    } else {
      console.log('FACTORY/POOL CONSISTENCY: REVIEW REQUIRED');
    }

    console.log('Position Manager deployed:', managerExists);
    console.log('Router deployed:', routerExists);

    console.log('\nNO TRANSACTIONS SENT.');
    console.log('NO TOKENS MOVED.');
    console.log('NO APPROVALS REQUESTED.');

  } finally {
    await provider.destroy();
  }
}

main().catch(err => {
  console.error('\nAUDIT ERROR:', err.shortMessage || err.message);
  process.exitCode = 1;
});
