## P.Y.E.

The PYE token is an ERC1155 Token that creates a new Staking position contract on every staking deposit.

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

## Contracts

- Pye Token ERC1155
  - Token issuance and position contract creation
  - Single point of Access to all position contracts ever created
- Position Contract
  - Proxy contract of SW adapter holding SW shares on deposit and Assets on ustake
- SW Adapter
  - Contract logic to interact with SW vaults, does not manage funds
- Pye Registry
  - Management of WL adapters & fees, predefined maturity timestamps,
  - Creates beacon proxy contracts from each staking provider

## Deploymets

| Contract            | Date     | Chains                                                                                     |
| ------------------- | -------- | ------------------------------------------------------------------------------------------ |
| PyeRouterV1         | Jul 23th | [Holesky](https://holesky.etherscan.io/address/0x574bf19d0386d5924217ace966d72e3e555afc0f) |
| StakeWiseAdapter    | Jul 23th | [Holesky](https://holesky.etherscan.io/address/0xe5fdcf678928b31d44fce21e0513df6f0d09895b) |
| SW Adapter (Beacon) | Jul 23th | [Holesky](https://holesky.etherscan.io/address/0xf54756faee5f713a0ff22bf411737136d191388f)|

## Metadata testing


## Commits

| version | hash                                     |
| ------- | ---------------------------------------- |
| v1 | d34e60a6b77ad27835e4019bb18820f2153a9abd |

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

#### Test

`forge t`

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
