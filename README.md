# Verdict — Prediction Markets

> Verdict settles questions against real outcomes. Create a market, seed liquidity on both sides, buy YES or NO shares, and resolve no-questions-asked from an on-chain outcome source.

## What it does

Verdict settles questions against real outcomes. Create a market, seed liquidity on both sides, buy YES or NO shares, and resolve no-questions-asked from an on-chain outcome source. The entire lifecycle lives in one contract, every button in the UI calls a real function on it — there is no mock backend.

## Contract

| | |
|---|---|
| File | `contracts/PredictionMarkets.sol` |
| Contract name | `PredictionMarkets` (inherits `ReentrancyGuard`) |
| Solidity | `^0.8.20` |
| State functions | 9 (of which 2 payable) |
| Deployed (mainnet 677) | not yet deployed — placeholder `0x000…000` |

### Function surface

| Function | Type | Returns |
|---|---|---|
| `createMarket` | write | uint256 |
| `_open` | write | result / revert |
| `buyYes` | payable | tx receipt |
| `buyNo` | payable | tx receipt |
| `resolve` | write | result / revert |
| `claimWinnings` | write | result / revert |
| `marketInfo` | view | address creator, string memory question, uint256 deadline, bool resolved, uint8 outcome, uint256 yesPool, uint256 noPool, uint256 positionCount |
| `marketCount` | view | uint256 |
| `positionCount` | view | uint256 |

### Events

| Event | Signature |
|---|---|
| `MarketCreated` | (uint256 indexed mid, address indexed creator, string question, uint256 deadline, address oracle) |
| `PositionOpened` | (uint256 indexed mid, uint256 indexed pid, address indexed user, bool isYes, uint256 amount) |
| `MarketResolved` | (uint256 indexed mid, uint8 outcome, uint256 yesPool, uint256 noPool) |
| `WinningsClaimed` | (uint256 indexed mid, uint256 indexed pid, address indexed user, uint256 payout) |

## Network

| | |
|---|---|
| Chain | BOT Chain Mainnet (chainId `677`) |
| RPC | `https://rpc.botchain.ai` |
| Explorer | `https://scan.botchain.ai` |
| Native currency | BOT (18 decimals) |
| Testnet | BOT Chain Testnet (chainId `968`) - `https://rpc.bohr.life` |

## Frontend

- **Wallet connection** - [Reown/AppKit](https://reown.com) (Web3Modal v2, inline modal, `subscribeAccount` / `subscribeNetwork`)
- **Web3 library** - ethers.js v6 (`BrowserProvider`, `Contract`, `parseEther`)
- **Animation** - GSAP 3 + ScrollTrigger (`expo.out` entrances, `prefers-reduced-motion` fallback renders content instantly)
- **Zero build step** - single `index.html`, CDN imports via ESM import map; no bundler, no framework runtime
- **Accessibility** - auto-generated `aria-label`s on all binary and form controls, focus-visible styles, button busy states

## Run it locally

```bash
git clone https://github.com/Henoch4/PredictionMarkets.git
cd PredictionMarkets
# open the frontend directly (no build step)
start frontend/index.html   # Windows
# or serve it if your browser blocks file:// modules:
npx serve frontend
```

> **Note** — contract addresses: the UI reads its deploy target from the `CA` constant at the top of the inline script. Until the contract is deployed to mainnet 677, the demo runs against the deterministic sample data built into the page; after deployment, set `CA['677']` to the real address and every button goes live.