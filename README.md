## PYE - split eth staking into principal and yield lst's

Pye enables users to separate principal and yield from staking positions into two distinct, independently tradable tokens. By integrating with StakeWise v3 vaults, P.Y.E. transforms a single ETH staking position into liquid derivatives that unlock new trading and hedging strategies.

### Overview

When users deposit ETH through P.Y.E., the protocol:

- Stakes the ETH in StakeWise v3 validators
- Issues **Principal Tokens (PT)** representing 1:1 claim on deposited capital
- Issues **Yield Tokens (YT)** representing claims on future staking rewards
- Locks the position until a specified maturity date

This separation enables PT holders to access their principal liquidity while YT holders speculate on or hedge future yield. Upon maturity, token holders can redeem their respective tranches based on the actual yield generated during the staking period.

### Key Features

- **Yield Tokenization**: Separate trading of principal and yield streams
- **Time-Based YT Issuance**: YT amount scales with time-to-maturity (1 year = 100% of principal in YT)
- **Flexible Maturities**: Create positions with custom maturity dates
- **StakeWise Integration**: Leverage battle-tested staking infrastructure
- **Exit Queue Management**: Automated handling of StakeWise's ~8-day withdrawal process
- **Fee Mechanism**: Protocol fees on minting and redemption

### Use Cases

- **Principal Holders**: Lock in staking exposure while maintaining capital liquidity
- **Yield Speculators**: Trade future staking rewards without locking principal
- **Rate Hedging**: Hedge against changing staking yields
- **Liquidity Providers**: Enhanced strategies using separated tranches

### Yield Source

The yield in P.Y.E. comes from **Ethereum staking rewards** through StakeWise v3 vaults:

1. **Deposit**: Your ETH is staked in StakeWise validators, receiving shares
2. **Accumulation**: Shares increase in value from:
   - Consensus layer rewards (validator rewards)
   - Execution layer rewards (MEV + priority fees)
3. **Realization**: Upon unstaking, shares convert back to ETH at appreciated rate
4. **Distribution**: `Yield = Total ETH received - Original Principal`

**Example**: Deposit 1 ETH for 1 year → Receive 1 PT + 1 YT. After staking generates 4% yield → PT holders redeem 1 ETH (principal), YT holders redeem 0.04 ETH (yield).

P.Y.E. doesn't generate yield itself—it simply **splits StakeWise staking rewards** into separate tradable tokens.

## Architecture

### Contract Structure

#### **PyeRouterV1** - Main Entry Point & Registry

`src/PyeRouterV1.1.sol`

- Central router for all user interactions (deposit, requestUnstake, unstake, redeem)
- Creates and manages bonds via BeaconProxy pattern for each (validatorVault, maturity) pair
- Whitelists StakeWise validator vaults
- Configures protocol fees (mintFee, redemptionFee)
- Stores mappings of bonds and validates user access

#### **StakeWiseAdapter** - Bond Implementation (BeaconProxy)

`src/adapters/StakeWise/StakeWiseAdapter.sol`

- Individual bond lifecycle management
- Deposits ETH into StakeWise vault and receives shares
- Creates PT and YT tokens for depositors
- Manages StakeWise exit queue (requestUnstake, unstake)
- Calculates yield split and processes redemptions
- Each (validatorVault, maturity) pair gets its own bond instance

#### **PTv1** - Principal Token (ERC20)

`src/tokens/PTv1.sol`

- Represents 1:1 claim on deposited principal
- Minted on deposit, burned on redemption
- Optional transfer lock mechanism (`isPtLocked`) via `_beforeTokenTransfer` hook
- Access control: Only the bond contract that deployed it can mint/burn (`onlyBond` modifier)
- Immutable bond reference set at deployment

#### **YTv1** - Yield Token (ERC20)

`src/tokens/YTv1.sol`

- Represents proportional claim on future yield
- Amount based on time-to-maturity formula: `ytAmount = (maturity - now) * principal / 365 days`
- 1 year lock = 100% of principal in YT (1 ETH deposit → 1 YT)
- 6 months lock = 50% of principal in YT (1 ETH deposit → 0.5 YT)
- Minted on deposit, burned on redemption
- Access control: Only the bond contract that deployed it can mint/burn (`onlyBond` modifier)

### Token Mechanics

**PT (Principal Token)**:

- 1:1 with deposit amount
- After maturity: redeemable for underlying ETH (minus fees)
- Location: `StakeWiseAdapter.sol:138`

**YT (Yield Token)**:

- Calculated using RAY precision (1e27) for accuracy
- Formula: `period * (principal.rayDiv(ONE_YEAR_SECONDS)) / RAY_PRECISION`
- After unstake: proportionally redeemable against yield tranche
- Location: `StakeWiseAdapter.sol:362-366`

## Deploymets

| Contract            | Date     | Chains                                                                                     |
| ------------------- | -------- | ------------------------------------------------------------------------------------------ |
| PyeRouterV1         | Jul 23th | [Holesky](https://holesky.etherscan.io/address/0x574bf19d0386d5924217ace966d72e3e555afc0f) |
| StakeWiseAdapter    | Jul 23th | [Holesky](https://holesky.etherscan.io/address/0xe5fdcf678928b31d44fce21e0513df6f0d09895b) |
| SW Adapter (Beacon) | Jul 23th | [Holesky](https://holesky.etherscan.io/address/0xf54756faee5f713a0ff22bf411737136d191388f) |

## Metadata testing

## Commits

| version | hash                                     |
| ------- | ---------------------------------------- |
| v1      | d34e60a6b77ad27835e4019bb18820f2153a9abd |

## Deployment

Load env vars

```
sounrce .env
```

Run deployment script

```
forge script script/SystemDeploy.s.sol:SystemDeploy  --rpc-url $HOLESKY_URL  --chain holesky  --broadcast --verify
```

## Properties

- Create position:

  - 0.- Access anyone
  - 1.- Every single deposit creates and locks capital until maturity.
  - 2.- Only one (the initial) deposit can be made to the position contract.
  - 3.- pT token issuance amount is 1:1 with deposit
  - 4.- yT token issuance amount depends on time elapsed between present time & maturity, ref APY
  - 5.- Maturities are predefined unix timestamps (ie: 1/4 year)

- After maturity
  - Request Unstake:
    - 0.- Access: any PYE token holder with 1 or more PYE tokens balance
    - 1.- Triggers enter exit queue for total amount of shares
    - 2.- Triggered only once and following attemps are blocked if 1 request ticket exists
    - 3.- Shares KEEPS generating yield while on exit queue (delay time ~8 days on SW)
  - Unstake
    - 0.- Access: any PYE token holder with 1 or more PYE tokens balance
    - 1.- Triggers fund transfer of total shares (in underlying) to the position contract
    - 2.- Can be triggered as long as there is left shares in the queue, 2nd call will revert if no left shares
    - 3.- Unstaked assets define principal & yield tranches to redeem from
    - 4.- User selected yield % is applied to principal & yield tranches
    - 5.- Position STOPS generating yield
  - Redeem
    - 0.- Access: PYE holder with >= shares to redeem
    - 1.- Reverts if left shares exists in SW queue
    - 2.- Calculates shares to assets at SW rates
    - 3.- Based on PYE tokenId deducts from p/y tranche
      - assets must be always less than p/y tranche
    - 4.- Transfers assets to user
      - PYE tokens are burned

---

## Stake Wise Adapter

In Stake Wise system (SW) the Oracles periodically vote for the rewards/penalties accumulated by the Vaults in the Beacon Chain and execution rewards (MEV & priority fees) for the Vaults connected to the smoothing pool.

Once oracles submit a new Merkle tree root to the Keeper contract, every Vault can pull these updates by calling vault.updateState. The state becomes outdated once the Vault hasn't pulled two consequent updates.
[Reference.](https://docs.stakewise.io/for-developers/oracles#vault-state)

Therefore, the PYE Front End, prior to deposit into StakeWise vaults, must ensure the vault has been updated, and if not, query the `HarvestParams` to update it. This can be done thorugh a the back end server request.

To deposit through the PYE contracts, the `createPosition` on the main `Pye` contract takes the following params:

- `Eth value`: etherscan will add ether value as extra param field
- `address provider`: The Beacon contract of the adapter implementation In latest version is [0x28AF1BAD4E1dE8b4550Ab1B204fEF625bDeCbF15](https://holesky.etherscan.io/tx/0x38b50fd3c0731f6d542ff0817281351cedbb4969b6c57358b2dc1346e85706aa)
- `uint256 amount` : The amount to stake
- `uint80 ptYieldPercent`: The percentage of yield assigned to the pToken (basis points)
- `uint80 maturity`: Future date in unix timestamp. (min 1 week & max 5 years)
- `bytes calldata data`: Arbitrary data needed for each specific implementation

Note: In this SW test case, the `HarvestParams` are passed to the `createPosition` call through the data field.
Only if the vault requires to be updated. These params must be encoded into a single `bytes calldata data` field. If no update required use `0x`.

#### How to know if vault requires an update (2 options)

- By querying the Vault function [isStateUpdateRequired()](https://github.com/stakewise/v3-core/blob/ed1a44f0c9b44a1cafcf33ee9485f90040c759ca/contracts/interfaces/IVaultState.sol#L90)

- By querying the Keepers contract and passing the vault as parameter to function [isHarvestRequired()](https://github.com/stakewise/v3-core/blob/ed1a44f0c9b44a1cafcf33ee9485f90040c759ca/contracts/interfaces/IKeeperRewards.sol#L158)

- The `HarvesParams` are the following:

  ```
  struct HarvestParams {
      bytes32 rewardsRoot;
      int160 reward;
      uint160 unlockedMevReward;
      bytes32[] proof;
  }
  ```

  - The `bytes32 rewardsRoot` param is available at the `keepers contract` function `rewardsRoot()`.
  - The `int160 reward` param is available from the subgraph bellow by the name of `proofReward`
  - The `uint160 unlockedMevReward` param is available from the subgraph bellow by the name of `proofUnlockedMevReward`
  - The `bytes32[] proof` param is available from the subgraph bellow.
  - [Reference.](https://github.com/stakewise/v3-core/blob/ed1a44f0c9b44a1cafcf33ee9485f90040c759ca/contracts/interfaces/IKeeperRewards.sol#L94)

### Addresses

- Mainnet
  - Vault (to define)
  - Keeper [0x6B5815467da09DaA7DC83Db21c9239d98Bb487b5](https://etherscan.io/address/0x6B5815467da09DaA7DC83Db21c9239d98Bb487b5)
- Holesky
  - Vault [0x472D1A6342E007A5F5E6C674c9D514ae5A3a2fC4](https://holesky.etherscan.io/address/0x472D1A6342E007A5F5E6C674c9D514ae5A3a2fC4)
    - Note that this vault was randomly picked for PYE testing.
  - Keeper [0xB580799Bf7d62721D1a523f0FDF2f5Ed7BA4e259](0xB580799Bf7d62721D1a523f0FDF2f5Ed7BA4e259)

### Subgraphs

Note that the addesses passed to the subgraoh query must be in lowercase, an address from etherscan will be checksumed and therefore uppercased so it will fail the graphql query.

- Mainnet: [Subgraph for Rewards, Proof and MevRewards](https://mainnet-graph.stakewise.io/subgraphs/name/stakewise/stakewise/graphql?query=%7B%0A++vaults%28where%3A+%7Bid%3A+%220x1b3ce55dde0e0d4b9a200855406e7b14334c10b0%22%7D%29+%7B%0A++++proofUnlockedMevReward%0A++++proof%0A++++proofReward%0A++%7D%0A%7D)
- Holesky:
  [Subgraph for Rewards, Proof and MevRewards](https://holesky-graph.stakewise.io/subgraphs/name/stakewise/stakewise/graphql?query=%7B%0A++vaults%28where%3A+%7Bid%3A+%220x472d1a6342e007a5f5e6c674c9d514ae5a3a2fc4%22%7D%29+%7B%0A++++proofUnlockedMevReward%0A++++proof%0A++++proofReward%0A++%7D%0A%7D)

Reference: [Query through http - The graph Docs.](https://thegraph.com/docs/en/querying/querying-from-an-application/)

### Contract Utils (Only for testing)

For testing and verify the validity of the `HarvestParams` proof, the `Pye` contract has the following read methods prefixed with `_`:

- `encodeHarvestParams(...)`: takes the harvest params described above and encodes them into a single `bytes calldata data` field
- `_verifyRewardsProof(...)`: takes the harvest params described above and returns a boolean weather the proof is valid for the params inclusion in the merkle tree.
- `_time()` the current blockchain timestamp for quick calculation of positions maturity

#### Test

`forge t`

---

## Development

To run locally

```ssh
forge install
forge build
forge test
```

Format on save with VSC by adding this to your settings.json

```json
"[solidity]": {

    "editor.defaultFormatter": "JuanBlanco.solidity"
  },
  "editor.formatOnSave": true,
  "solidity.formatter": "forge",
  "typescript.updateImportsOnFileMove.enabled": "always",
  "[rust]": {
    "editor.defaultFormatter": "rust-lang.rust-analyzer",
    "editor.formatOnSave": true
  }
```
