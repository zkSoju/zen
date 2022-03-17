# zen ⛩️ • [![tests](https://github.com/zksoju/zen/actions/workflows/tests.yml/badge.svg)](https://github.com/zksoju/zen/actions/workflows/tests.yml) [![lints](https://github.com/zksoju/zen/actions/workflows/lints.yml/badge.svg)](https://github.com/zksoju/zen/actions/workflows/lints.yml)

Introducing Zen, Zen is the garden inclusive and zero fee swapping mechanism for the Azuki community. Have peace of mind whilst finding your forever bean. Built by the community, for the community. _IKZ!_

[Website](https://zenswap.xyz/)

Refer to https://github.com/zkSoju/zen-next for the dApp.

## Features

-   [ ] Swap mechanic
    -   [x] Base swap functionality (ERC721A)
    -   [x] Ownership validation
    -   [x] $BOBU support
-   [ ] Testing suite
    -   [x] Isolated `createSwap` and `acceptSwap` tests
    -   [x] Composite ERC721 + ERC1155 tests
    -   [x] Isolated ERC721 Tests
    -   [x] Isolated ERC1155 Tests (shouldn't be able to swap?)
    -   [ ] Test invalid swaps and cancelations
    -   [ ] Test ownership and swap validation

## Gas Usage

At gas prices `(61 gwei/gas)` at `$2,524/ETH` conversion rate the following are prices on average:

-   **Create a swap:** ~~$16.91 (109841 gas)~~
-   **Accept a swap:** ~~$8.60 (55908 gas)~~
-   **Cancel a swap:** ~~$1.75 (11391 gas)~~

![snapshot](/snapshots/6.png)

## Blueprint

```ml
lib
├─ ds-test — https://github.com/dapphub/ds-test
├─ forge-std — https://github.com/brockelmore/forge-std
├─ solmate — https://github.com/Rari-Capital/solmate
├─ clones-with-immutable-args — https://github.com/wighawag/clones-with-immutable-args
src
├─ tests
│  └─ Zen.t — "Zen Tests"
└─ Zen — "Core Swapping Mechanism"
```

## Development

**Setup**

First set the `ETH_RPC_URL` with an Alchemy or Infura RPC URK in `.env` as shown in `.env.example`. Test suite will be ran on a fork of the mainnet.

```bash
make
# OR #
make setup
```

**Building**

```bash
make build
```

**Testing**

```bash
make test
```

**Deployment & Verification**

Inside the [`scripts/`](./scripts/) directory are a few preconfigured scripts that can be used to deploy and verify contracts.

Scripts take inputs from the cli, using silent mode to hide any sensitive information.

NOTE: These scripts are required to be _executable_ meaning they must be made executable by running `chmod +x ./scripts/*`.

NOTE: For local deployment, make sure to run `yarn` or `npm install` before running the `deploy_local.sh` script. Otherwise, hardhat will error due to missing dependencies.

NOTE: these scripts will prompt you for the contract name and deployed addresses (when verifying). Also, they use the `-i` flag on `forge` to ask for your private key for deployment. This uses silent mode which keeps your private key from being printed to the console (and visible in logs).

---

### First time with Forge/Foundry?

See the official Foundry installation [instructions](https://github.com/gakonst/foundry/blob/master/README.md#installation).

Don't have [rust](https://www.rust-lang.org/tools/install) installed?
Run

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

Then, install the [foundry](https://github.com/gakonst/foundry) toolchain installer (`foundryup`) with:

```bash
curl -L https://foundry.paradigm.xyz | bash
```

Now that you've installed the `foundryup` binary,
anytime you need to get the latest `forge` or `cast` binaries,
you can run `foundryup`.

So, simply execute:

```bash
foundryup
```

🎉 Foundry is installed! 🎉

---

### Writing Tests with Foundry

With [Foundry](https://gakonst.xyz), tests are written in Solidity! 🥳

Create a test file for your contract in the `src/tests/` directory.

For example, [`src/Greeter.sol`](./src/Greeter.sol) has its test file defined in [`./src/tests/Greeter.t.sol`](./src/tests/Greeter.t.sol).

To learn more about writing tests in Solidity for Foundry and Dapptools, reference Rari Capital's [solmate](https://github.com/Rari-Capital/solmate/tree/main/src/test) repository largely created by [@transmissions11](https://twitter.com/transmissions11).

### Configure Foundry

Using [foundry.toml](./foundry.toml), Foundry is easily configurable.

For a full list of configuration options, see the Foundry [configuration documentation](https://github.com/gakonst/foundry/blob/master/config/README.md#all-options).

## License

[AGPL-3.0-only](https://github.com/abigger87/femplate/blob/master/LICENSE)

## Acknowledgements

-   [erc721a](https://github.com/chiru-labs/ERC721A)
-   [femplate](https://github.com/abigger87/femplate)
-   [foundry](https://github.com/gakonst/foundry)
-   [solmate](https://github.com/Rari-Capital/solmate)
-   [forge-std](https://github.com/brockelmore/forge-std)
-   [clones-with-immutable-args](https://github.com/wighawag/clones-with-immutable-args).
-   [foundry-toolchain](https://github.com/onbjerg/foundry-toolchain) by [onbjerg](https://github.com/onbjerg).
-   [forge-template](https://github.com/FrankieIsLost/forge-template) by [FrankieIsLost](https://github.com/FrankieIsLost).
-   [Georgios Konstantopoulos](https://github.com/gakonst) for [forge-template](https://github.com/gakonst/forge-template) resource.
