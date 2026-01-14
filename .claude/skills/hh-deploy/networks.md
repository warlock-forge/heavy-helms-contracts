# Network Configuration

This file contains STABLE infrastructure addresses that don't change between deployments.

## Chain IDs

| Network | Chain ID | Type |
|---------|----------|------|
| Base Mainnet | 8453 | Production |
| Base Sepolia | 84532 | Testnet |

## Chainlink VRF Infrastructure

These are Chainlink infrastructure addresses and our subscription IDs. All public on-chain data.

### Base Sepolia (84532)

| Component | Value |
|-----------|-------|
| VRF Coordinator | `0x5C210eF41CD1a72de73bF76eC39637bB0d3d7BEE` |
| Key Hash | `0x9e1344a1247c8a1785d0a4681a27152bffdb43666ae5bf7d14d24a5efd44bf71` |
| Subscription ID | `45119898891637739442171324623719174374501521647423536596434539103126041787269` |

### Base Mainnet (8453)

| Component | Value |
|-----------|-------|
| VRF Coordinator | `0xd5D517aBE5cF79B7e95eC98dB0f0277788aFF634` |
| Key Hash | `0x00b81b5a830cb0a4009fbd8904de511e28631e62ce5ad231373d3cdad373ccab` |
| Subscription ID | `27361008628583863589436325876377444619816096620825509261807088488716278379485` |

## VRF Dashboard Links

- Base Sepolia: https://vrf.chain.link/base-sepolia
- Base Mainnet: https://vrf.chain.link/base

## RPC Endpoints

Stored in `.env` file as `RPC_URL`. Not committed to repo.

Common providers:
- Alchemy
- Infura
- QuickNode
- Public RPC (not recommended for production)
