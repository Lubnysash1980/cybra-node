'use strict';

require('dotenv').config();
const { ethers } = require('ethers');

const RPC = process.env.BSC_RPC_URL ||
    'https://bsc-rpc.publicnode.com';

const TOKEN_ADDR = (
    process.env.TOKEN_ADDR ||
    '0x74dA52028E42A37bc89E05c2fD5c52daBE4CB48f'
).toLowerCase();

const QUOTE_ADDR = (
    process.env.QUOTE_ADDR ||
    '0x55d398326f99059fF775485246999027B3197955'
).toLowerCase();

const FACTORY_ADDR =
    '0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865';

const FEE = Number(process.env.FEE_TIER || 2500);

const FACTORY_ABI = [
    'function getPool(address,address,uint24) view returns (address)',
    'function feeAmountTickSpacing(uint24) view returns (int24)'
];

const POOL_ABI = [
    'function token0() view returns (address)',
    'function token1() view returns (address)',
    'function fee() view returns (uint24)',
    'function tickSpacing() view returns (int24)',
    'function slot0() view returns (uint160 sqrtPriceX96,int24 tick,uint16 observationIndex,uint16 observationCardinality,uint16 observationCardinalityNext,uint8 feeProtocol,bool unlocked)',
    'function liquidity() view returns (uint128)'
];

const ERC20_ABI = [
    'function decimals() view returns (uint8)',
    'function symbol() view returns (string)',
    'function name() view returns (string)'
];

function section(title) {
    console.log('\n========== ' + title + ' ==========');
}

function formatPrice(sqrtPriceX96, decimals0, decimals1) {
    // BigInt arithmetic avoids Number precision loss.
    const Q192 = 1n << 192n;
    const numerator = sqrtPriceX96 * sqrtPriceX96;

    const scale0 = 10n ** BigInt(decimals0);
    const scale1 = 10n ** BigInt(decimals1);

    const precision = 10n ** 18n;

    const token1PerToken0 =
        numerator * scale0 * precision /
        (Q192 * scale1);

    const token0PerToken1 =
        numerator === 0n
            ? 0n
            : Q192 * scale1 * precision /
              (numerator * scale0);

    return {
        token1PerToken0:
            (Number(token1PerToken0) / 1e18).toFixed(12),
        token0PerToken1:
            (Number(token0PerToken1) / 1e18).toFixed(12)
    };
}

async function main() {
    console.log('====================================');
    console.log(' CYBRA MINT V3 DIAGNOSTIC v3');
    console.log(' READ ONLY — NO TRANSACTIONS');
    console.log('====================================');

    if (!ethers.isAddress(TOKEN_ADDR) ||
        !ethers.isAddress(QUOTE_ADDR) ||
        !ethers.isAddress(FACTORY_ADDR)) {
        throw new Error('Invalid contract address');
    }

    const provider = new ethers.JsonRpcProvider(RPC);

    section('NETWORK');

    const network = await provider.getNetwork();

    console.log('Chain ID:', network.chainId.toString());

    if (network.chainId !== 56n) {
        throw new Error('Wrong network. Expected BNB Chain 56.');
    }

    console.log('RPC:', RPC);

    const factory = new ethers.Contract(
        FACTORY_ADDR,
        FACTORY_ABI,
        provider
    );

    const token0Address =
        BigInt(TOKEN_ADDR) < BigInt(QUOTE_ADDR)
            ? TOKEN_ADDR
            : QUOTE_ADDR;

    const token1Address =
        token0Address === TOKEN_ADDR
            ? QUOTE_ADDR
            : TOKEN_ADDR;

    section('TOKENS');

    async function tokenInfo(address) {
        const token = new ethers.Contract(
            address,
            ERC20_ABI,
            provider
        );

        const [symbol, name, decimals] =
            await Promise.all([
                token.symbol(),
                token.name(),
                token.decimals()
            ]);

        return {
            address,
            symbol,
            name,
            decimals: Number(decimals)
        };
    }

    const [token0, token1] = await Promise.all([
        tokenInfo(token0Address),
        tokenInfo(token1Address)
    ]);

    console.log('Token0:', token0.symbol, token0.address);
    console.log('Name0:', token0.name);
    console.log('Decimals0:', token0.decimals);

    console.log('Token1:', token1.symbol, token1.address);
    console.log('Name1:', token1.name);
    console.log('Decimals1:', token1.decimals);

    section('FACTORY');

    const [poolAddress, spacing] = await Promise.all([
        factory.getPool(token0Address, token1Address, FEE),
        factory.feeAmountTickSpacing(FEE)
    ]);

    console.log('Factory:', FACTORY_ADDR);
    console.log('Fee:', FEE);
    console.log('Tick spacing:', spacing.toString());
    console.log('Pool:', poolAddress);

    if (poolAddress === ethers.ZeroAddress) {
        console.log('RESULT: Pool does not exist in this factory.');
        return;
    }

    section('POOL CONTRACT');

    const code = await provider.getCode(poolAddress);

    console.log('Contract code exists:', code !== '0x');

    if (code === '0x') {
        throw new Error('Pool address has no contract code');
    }

    const pool = new ethers.Contract(
        poolAddress,
        POOL_ABI,
        provider
    );

    const [
        actualToken0,
        actualToken1,
        actualFee,
        actualSpacing,
        slot,
        liquidity
    ] = await Promise.all([
        pool.token0(),
        pool.token1(),
        pool.fee(),
        pool.tickSpacing(),
        pool.slot0(),
        pool.liquidity()
    ]);

    section('LIVE STATE');

    console.log('Token0 matches:',
        actualToken0.toLowerCase() === token0Address);

    console.log('Token1 matches:',
        actualToken1.toLowerCase() === token1Address);

    console.log('Fee:', actualFee.toString());
    console.log('Tick spacing:', actualSpacing.toString());

    console.log('Current tick:', slot.tick.toString());
    console.log('sqrtPriceX96:', slot.sqrtPriceX96.toString());
    console.log('Initialized:', slot.sqrtPriceX96 !== 0n);
    console.log('Unlocked:', slot.unlocked);

    console.log('Active liquidity:', liquidity.toString());

    section('NORMALIZED PRICE');

    const price = formatPrice(
        slot.sqrtPriceX96,
        token0.decimals,
        token1.decimals
    );

    console.log(
        `${token1.symbol} per ${token0.symbol}:`,
        price.token1PerToken0
    );

    console.log(
        `${token0.symbol} per ${token1.symbol}:`,
        price.token0PerToken1
    );

    section('400M TARGET CHECK');

    const targetPrice = 1 / 400000000;

    const targetTick = Math.round(
        Math.log(targetPrice) / Math.log(1.0001)
    );

    const currentTick = Number(slot.tick);
    const spacingNumber = Number(actualSpacing);

    const lowerTick =
        Math.floor((targetTick - 1000) / spacingNumber) *
        spacingNumber;

    const upperTick =
        Math.floor((targetTick + 1000) / spacingNumber) *
        spacingNumber;

    console.log('Target:', '400000000 USDT per CYBRA');
    console.log('Target tick:', targetTick);
    console.log('Proposed lower tick:', lowerTick);
    console.log('Proposed upper tick:', upperTick);
    console.log('Current tick:', currentTick);

    if (currentTick > upperTick) {
        console.log('POSITION COMPOSITION: token0 only');
    } else if (currentTick < lowerTick) {
        console.log('POSITION COMPOSITION: token1 only');
    } else {
        console.log('POSITION COMPOSITION: both tokens may be needed');
    }

    section('FINAL DIAGNOSTIC');

    if (liquidity === 0n) {
        console.log('WARNING: Active pool liquidity is ZERO.');
    } else {
        console.log('Pool reports nonzero active liquidity.');
    }

    if (slot.sqrtPriceX96 === 0n) {
        console.log('WARNING: Pool price is not initialized.');
    }

    console.log('\nNo transactions were sent.');
    console.log('No tokens were transferred.');
    console.log('No approvals were requested.');
    console.log('CYBRA main pool was not modified.');

    await provider.destroy();
}

main().catch(error => {
    console.error('\nDIAGNOSTIC ERROR:', error.shortMessage || error.message);
    process.exitCode = 1;
});
