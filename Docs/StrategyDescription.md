# Alchemix multiplier strategy

## Abstract
The core idea is to leverage what is deposited into the strategy, using Alchemix smart contracts.

Let's assume we have a base asset like WBTC for which we want to generate yield for, to do this we first either generate Dai using Maker smart contracts or borrow Dai[^1] using WBTC. We now have Dai, then in the second step we double the borrowed Dai using the below described algorithm (by the use of Alchemix smart contracts), at the same time we have deposited the doubled Dai to Alchemix, in the last step we collect the yield from Alchemix by minting alUSD and then exchanging the resulting alUSD to WBTC and repeating the procedure. This may result in some yields, for example if WBTC generates 0.39% APY and Dai generates 1.56% APY[^2], even if we generate Dai with 200% collateralization ratio (0.75 percent Annual fee on borrowed amount, 0.375 percent on doubled amount), when the Alchemix interest is generated (which is about double of yearn Dai vault interest minus Alchemix fees, because we have doubled our Dai and also some Alchemix internals), better rates than WBTC is achievable (it is also an alternate strategy and adds diversification).

The same idea could be applied to other base assets and other Alchemix V2 supported assets, more detailed in section “Some supported delegate paths”.

## Doubling[^3] the generated Dai
To double the generated (borrowed) Dai[^4], there are different methods, at least two of them are:
I think the better method to use is to get a flash loan for double of the original borrowed value, deposit it to Alchemix, mint alUSD for the half (the same amount we borrowed originally), then exchange alUSD for the base asset, and put this exchanged amount and the borrowed one together and return the flash loan back. We now have the desired Alchemix position. There may be some details in flash loan and exchange process including some fees, which needs to be addressed later.
The other method would be to deposit the borrowed Dai, mint half of it, exchange it to Dai, deposit it again, and repeat the process until the fees get higher than the amount to be deposited. The sum of deposited amount would be (1 + ½ + ¼ + 1/8 + …) of original borrowed Dai, this sum if it goes to infinite will become 2, which means we will deposit 2*Borrowed Dai.

## Collecting the Yield
To collect the generated yield, the available amount to be mined, is minted and exchanged to base asset, and reinvested.
Getting back the Original investment
To get back the original Dai[^5], we liquidate our position, for the required amount, and claim the required amount of deposited asset (The position with Alchemix is decreased by 2* (required amount), half is paid back for loan, half is withdrawn).

## Requirements
If the strategy is to be executed automatically, our contract should be whitelisted by Alchemix, this requirement may be removed in future by Alchemix team.
V1 of Alchemix did not support smart contarcts for some operations, V2 have support, but requires whitelisting at least initially.

## Benefit to Alchemix
Alchemix will also benefit since the designed capacity of the al[Asset] will be filled and Alchemix can get its shares of generated yield.

## Some supported delegate paths
Ignoring the possibly profitability issues, following delegate paths are possible now and many more may come soon (If Alchemix starts supporting them)
- Delegating Dai to USDC
- Delegating USDC to Dai
- Delegating WETH to Dai
- Delegating WBTC to Dai
- Delegating tokens to Dai, WETH, USDC, USDT

## Delegation paths requiring caution
Since Alchemix uses yearn vaults itself for generation of yield, some delegation paths may require caution if to be used. For example for investment of Dai in Alchemix, since it ends up in Yearn Dai Vault, if applying the strategy to Yearn Dai vault is considered (The Dai coming from Dai vault itself), it would be a strategy eating its own tail.
When applying the strategy with same source and destination vaults, some or all of the assets may return back to the vault through Alchemix smart contracts. It should be taken care (also in withdrawals) that the amount coming from Alchemix either directly or through the Alchemix multiplier strategy is not reinvested to the Alchemix multiplier strategy again. Not maintaing such condition, will have side effects that should be studied separately. This self delegation may also be even less profitable for depositors in some scenarios. Please take a look at Concerns.md and SelfDelegationProfitabilityAnalysis.pdf for more information.

## An idea for development
Although development path should be studied more, an idea which may cover majority of cases, would be to develop a general architecture, accepting some configuration parameters like the base asset, the Alchemix supported asset, etc, and for each delegation path the contract could be configured accordingly.

## Some Risks
1. Risk of converting Bast asset to Alchemix supported asset, for example risk of makerdao smart contracts if we generate Dai using base asset, or risk of lender smart contracts (for example to lose collateral).
2. Can the contract be blacklisted after being whitelisted? There is a remove function in Iwhitelist.sol, but in AlchemistV2.sol, I can not find a reference to this remove function. When whitelisting is disabled, it could not be enabled again ( https://github.com/alchemix-finance/v2-contracts/blob/master/contracts/interfaces/IWhitelist.sol#L45 )
3. Risk of yield generating Vaults from Yearn.Finance (Already being addressed by Yearn.Finance)
4. Risk of Alchemix smart contracts (Contracts are audited, needs reference)
5. Management actions for Alchemix. Contracts are upgradable? I think yes, needs reference.
6. Risk of my contracts (No direct access from outside, only through Yearn.Finance; has different requirements in different levels of 10 million, 100 million, etc).

[^1]: Or another Alchemix supported token
[^2]: Rates displayed on yearn.finance in 22 March 2022
[^3]: Currently, maximum Alchemix LTV ratio is 50% . Leverage for other LTV ratios is also possible with different rates.
[^4]: The described process could be similarly adopted for other Alchemix supported asset
[^5]: Or similar asset supported by Alchemix