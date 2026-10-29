# Prediction Markets

**Parimutuel binary markets, settled by a named oracle.**

Live on **BOT Chain mainnet (chain ID 677)**.

| | |
|---|---|
| Contract | `0x5BB15C0aCF487f37d3B6B93102095CA215652e37` |
| Network | BOT Chain Mainnet |
| Chain ID | 677 |
| RPC | https://rpc.botchain.ai |
| Explorer | https://scan.botchain.ai/ |
| Website | https://botchain.ai |

## What it does

Each market holds a YES pool and a NO pool. When the oracle resolves, every winner claims their stake plus a pro-rata share of the losing pool. The entire pool is distributed — there is no house edge and no spread.

## Functions

- `createMarket(question, durationSeconds, oracle)`
- `buyYes(marketId) / buyNo(marketId) — payable`
- `resolve(marketId, outcome) — oracle only, outcome 1 = YES, 2 = NO`
- `claimWinnings(marketId) — pays stake + pro-rata share of the losing pool`

## Frontend

A single self-contained `index.html` — no build step, no bundler. Open it directly or serve the folder statically.

- Wallet connect through any injected EIP-1193 wallet (MetaMask, OKX Wallet).
- If chain 677 is not configured, the page offers to add it (`wallet_addEthereumChain`).
- Every number on the page is read live from the contract over JSON-RPC; nothing is mocked.
- All writes are sent from the connected account and confirmed before the UI refreshes.

```bash
# any static server works
npx serve .
```

## Contract

`contracts/PredictionMarkets.sol` — self-contained Solidity 0.8.20, no external imports. Reentrancy guard and ownership are declared inline so the file compiles standalone with `solc`.

## License

MIT
