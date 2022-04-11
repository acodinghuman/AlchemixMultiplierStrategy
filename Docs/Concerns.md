# Alchemix Multiplier Strategy Concerns

## Concern 1
There is a concern that the strategy uses Yearn itself to generate yield; in this document it is shown that non of the collected fees will decrease if the strategy is applied correctly, so nobody at Yearn will suffer from applying the strategy. The collected fees may also increase.

## Some assumptions
1. If a Yearn vault deposit limit is not reached, it means by depositing into it, total performance fee will increase (Although APY may decrease).
2. Although the assumption that using the strategy, Yearn funds being reinvested into itself may not always be correct, I will study the strategy with this assumption[^1] (at the time of this writing, funds deposited to Alchemix will end up into Yearn Vaults).
3. If the performance fees collected by each vault and the total management fee collected by all vaults are higher after applying the strategy than the same values before applying the strategy, I will assume the strategy is profitable and it could be applied.
4. It is assumed that the multiplication factor is ( x ) .

## Studied scenarios
Here, two different scenarios will be studied:
1. When the investment is a delegation from a vault to its own
2. When the investment is a delegation from one vault to another

## Comparison of fees before and after applying the strategies

### Management fee
1. Delegation from one vault to itself: There will always be an increase in management fee since there is no borrowing, and the deposited amount is doubled.
2. Delegation from one vault to another: if an amount is removed from a Yearn vault (from the source vault), and by using the removed amount as collateral, the second asset (for destination vault) is borrowed, by at most (x * 100) percent collateralization ratio, and then it is multiplied by (x) using Alchemix smart contracts and put in the second vault, the total amount deposited into Yearn is not changed or even increased, so the 2 percent of total amount is not changed, and thus we will have either the same amount of management fee or some increase here. It is important that the (x * 100) percent collaterization ratio is maintained.


### Performance fee
1. Delegation from a vault to itself: Since there is no asset change here and the invested amount just gets leveraged, and because of the assumption number 1, the collected performance fee will increase, and this is done by the already available strategies (except the Alchemix Multiplier) having more capital to work with, and the collected fees for Alchemix Multiplier strategy comes from what remains from yield after other strategies collect their fees.
2. Delegation from one vault to another: Similar ideas has been experienced by Yearn.finance, for example by the strategy StrategyMakerV2_ETH-C , ethereum is converted to Dai using MakerDAO and the resulting Dai is deposited in Dai vault. In the Alchemix multiplier strategy, there will be a multiplication factor. Since the value of delegated amount is taken care to be at least equivalent of what is removed from the source vault (by taking care of appropriate collarization ratio, for example at most (2 * x) percent, if the multiplication factor is x ), the APY from destination vault (which is probably higher by some orders of magnitude from what normally achievable in source vault) is reflected to source vault after Alchemix fees are reduced (Currently 10%). [As of this writing](https://archive.ph/r0MEP) ETH APY is shown as 1.25% and Dai APY is 2.52% , so delegation from ETH to Dai seems logical using the Alchemix Multiplier strategy.

[^1]: Alchemix [will add](https://alchemixfi.medium.com/yield-options-f9de930cac0e) other investment options than yearn.finance in future so the assumption of an investment from yearn.finance will always return back to yearn may not be totally correct.
