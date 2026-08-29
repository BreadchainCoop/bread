# Bread Token 

The Breadchain Stablecoin is an experiment in **lossless donations** or **crowdstaking** for the Breadchain Collective. The idea is that users mint BREAD which is pegged 1:1 with DAI however under the hood the DAI earns yield which is captured not by the token holders but the Breadchain Collective's public goods funding stream. Thus users who hold and transact with BREAD are actually continually donating to the Breadchain Collective's public goods funding stream.

The BREAD token v1 was deployed on Polygon PoS and the underlying yield generation source was Aave's lending market. Switching to Gnosis Chain and using sDAI as the underlying yield source has major benefits:

- Since xDAI is native gas token on Gnosis Chain, users don't need both the gas token and DAI in order to onboard.
- Since sDAI is the native yield source for xDAI, it's less variable yield and carries less risk than the Aave market. Yields are also generally much higher!

## Recipient restrictions

BREAD cannot be credited to the token contract's own address. `transfer`, `transferFrom`, both `mint` overloads and `claimYield` revert with `InvalidRecipient()` when the recipient is the token contract, so tokens can't be stranded there by a mistyped or copy-pasted recipient. The check lives in `_update`, so it covers every balance-changing path.

Native xDAI is a different case and is deliberately left alone. BREAD is deployed behind `EIP173ProxyWithReceive`, whose `receive()` accepts plain xDAI and never delegates to the implementation — that is a property of the already-deployed proxy and cannot be changed by upgrading the implementation. Rejecting native transfers outright would also break `burn()`, which is paid out by `wxDai.withdraw()` sending xDAI to the contract with empty calldata. So xDAI sent directly to the token contract is accepted and stays there; `rescueToken` only moves ERC20s. If it ever needs sweeping, a native rescue function can be added in a later implementation upgrade.

## Setup

clone and enter this repo then run:

```bash
forge install
```

```bash
forge compile
```

## Test

```bash
forge test --fork-url "https://rpc.gnosis.gateway.fm" -vv
```

create an account [here](https://www.quicknode.com/) and get a gnosis chain endpoint on the free tier to get running the test suite.
