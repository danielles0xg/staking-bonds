QA

Do we need to upgrade all positions from a single contract? yes beacon proxies

Contracts

1 .- Position Factory/Manager
        Deploys position proxy/clone of SW vault type (Diff maturity/validator)
        Tracks all positions addresses and maturities
        (multicall) Admin can trigger request unstake to get funds into position contract from SW vault

2 .- Position Contract
        Is Custom ERC4626 base
        Creates and Manages (mint/burn) 2 ERC20s (pt & yt)
        Manages shares in two pools (pt & yt)
        Manages enter/exit SW flows



Assumption
Every yt & pt are unique and different address for each position
Router 


Create position:

0.- Position is ERC4626 vault of underlying/eth and emits position Token yt & pt
1.- Every deposit points to diff position contract
2.- Muktiple deposits can be made to the position contract.
3.- pT token issuance amount is 1:1 with deposit
4.- yT token issuance amount depends on time elapsed between present time & maturity, ref APY
5.- Maturities are predefined unix timestamps (ie: 1/4 year)


 == After maturity ==

Request Unstake:

Unstake

Redeem




univ2

1. Core Contracts
    Factory Contract:

    Responsible for creating and indexing pairs.
    Holds the generic bytecode for pairs.
    Ensures only one pair per unique token combination.
    Contains logic to enable the protocol fee.
    Pair Contracts:

    Serve as automated market makers.
    Keep track of token reserves.
    Facilitate token swaps.
    Can be used to build decentralized price oracles.

2. Periphery Contracts
    Router Contract:

    Provides user-friendly functions for trading and liquidity management.
    Supports multi-pair trades and treats ETH as a first-class citizen.
    Offers meta-transactions for removing liquidity.
    Library:

    Offers convenience functions for data fetching and pricing.

3. Liquidity Pools
    Pools consist of reserves of two ERC-20 tokens.
    Liquidity providers (LPs) deposit an equivalent value of each token to receive pool tokens.
    Pool tokens represent a share of the pool and can be burned to withdraw reserves.

4. Automated Market Maker (AMM)
    Uses a Constant Product Market Maker model: ( x \cdot y = k ).
    Ensures the product of the reserves (x and y) remains constant.
    Facilitates trades based on the invariant formula.