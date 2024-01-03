## Trillion Contracts

Foundry-based repo for Trillion smart contracts.

## Getting Started

Install dependencies:

- Setup [`asdf`](https://asdf-vm.com/) to manage runtime versions locally (NodeJS, etc.)

Install Foundry:

```shell
curl -L https://foundry.paradigm.xyz | bash
```

Install the latest versions of Foundry tooling:

Install missing dependencies that are shown in the install output (ex: `brew install libusb`).

```shell
foundryup
```

Install the Solidity linter (`solhint`) we use, as a yarn dependency:

```shell
yarn install
```

Install the Slither static analysis tool (used to find vulnerabilities):

```shell
pip3 install slither-analyzer
```

Install `lcov` if you want to play with code coverage:

```shell
brew install lcov
```

### Dependency Updates

We use Dependabot for automated dependency updates. Dependabot scans for updates in our dependencies and auto-creates a PR to upgrade the dependency.

## Development

### Build

This command compiles all the smart contracts.

```shell
forge build
```

### Test

There are a lot of flags you could pass to `forge test` - but most of the time you'll be running one of these two commands. You should **always** run `forge test` before you commit code.

`--gas-report` gives a breakdown of the deploy cost of a smart contract and the call cost for each function, as long as that function is called in some test somewhere.

NOTE: The function call cost is based on the parameters provided in testing, so its up to you to write tests that are realistic for gas estimation purposes.

```shell
forge test
forge test --gas-report
```

#### Coverage

You can generate a quick coverage summary by running:

```shell
forge coverage
```

However, you likely may want to filter out "`*.s.sol`" script contracts and render a nice web UI to examine code coverage, which you can do using the `yarn` script I've written:

> NOTE: This requires having `lcov` installed locally through homebrew.

```shell
yarn coverage
```

### Code Formatting

Like Prettier for Solidity - you should **always** run this before you commit code.

```shell
forge fmt
```

### Smart Contract Linting

Solhint is a linter for our smart contracts. Run it like so:

```shell
yarn lint
```

### Static Analysis

Slither is a static analysis tool used to find potential smart contract vulnerabilities. Run it like so:

```shell
slither .
```

### Gas Snapshots

Generates the `.gas-snapshot` file - by running all the tests and counting how much gas is used by each test. This is very useful for regression testing, refactoring, and optimization - you should **always** run this before you commit code.

NOTE: This is _distinct and different_ from `forge test --gas-report`. The gas reporting function in `forge test` instruments the smart contracts under test and gives you accurate gas usage of the functionality you care about. `forge snapshot` gives you the gas usage _of the tests themselves_ (not the smart contracts under test) - which means if you do a lot of setup in one of your tests, that gas usage will be included in your `.gas-snapshot` but it wouldn't show up in `forge test --gas-report`.

```shell
forge snapshot
```

### Installing Smart Contract Dependencies

Any smart contracts that need to be used as dependencies (for example, OpenZeppelin) - should be installed using `forge install`. This will install them as a `git submodule`.

DO NOT use `yarn` to install smart contracts. The _only thing_ we use `yarn` for is to manage our Solidity linter `solhint`.

```shell
forge install
```

### Deploying a Contract

Example of how to deploy a simple contract using a Foundry script.

```shell
forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

To deploy `FiatToken`, enter the required env vars in `.env`, then run:

```shell
forge script script/DeployFiatToken.s.sol:DeployFiatToken --rpc-url $SEPOLIA_RPC_URL --broadcast --verify --ffi -vvvv
```

### Upgrading a Contract

If your contract is upgradeable, you can define a Foundry script to upgrade your contract. You will need to set the address of your proxy contract as an env var and use that in your script.

To upgrade `FiatToken`, set the `FIAT_TOKEN_PROXY_ADDRESS` in `.env` and update the current (e.g. `FiatTokenV1`) and new implementation contract name you want to upgrade to (e.g. `FiatTokenV2`) in `script/UpgradeFiateToken.s.sol`, and run:

```shell
forge script script/UpgradeFiatToken.s.sol:UpgradeFiatToken --rpc-url $SEPOLIA_RPC_URL --broadcast --verify --ffi -vvvv
```

## Foundry Tooling

### Chisel

Chisel is an advanced Solidity REPL shipped with Foundry. It can be used to quickly test the behavior of Solidity snippets on a local or forked network.

```shell
chisel <subcommand>
```

### Cast

Cast is Foundry's command-line tool for performing Ethereum RPC calls. You can make smart contract calls, send transactions, or retrieve any type of chain data - all from your command-line.

```shell
cast <subcommand>
```

### Anvil

Anvil is a local testnet node shipped with Foundry. You can use it for testing your contracts from frontends or for interacting over RPC.

```shell
anvil <subcommand>
```

## Documentation

- Foundry documentation: <https://book.getfoundry.sh/>
- Solhint linter documentation: <https://github.com/protofire/solhint>
- Slither static analysis documentation: <https://github.com/crytic/slither>

### Help

Foundry tooling has really good help documentation. Some examples:

```shell
forge --help
anvil --help
cast --help
chisel --help
```

## Publishing to NPM

> :warning: **Not Implemented**: We haven't published to NPM

To allow other systems in Trillion to build on top of these smart contracts, we publish this repository as a private npm package on the npm registry. Only git repositories setup with an NPM Token for the `trillion-x` organization on the npm registry will be able to install it as a dependency.

NOTE: The package does not include the Solidity code - it only includes the ABIs (Application Binary Interface) JSON files. The assumption is that the Dapp is using [ABIType](https://abitype.dev/) directly, or something built on top of it like [viem](https://viem.sh/) - and so it's only necessary to ship the ABIs.

### Required steps

You _do not_ need to edit anything in `package.json` or commit/push anything to the repo to cut a new NPM version. Publishing to NPM is taken care of by [this Github Action](.github/workflows/publish_npm.yml) which fires when a new Github release is cut.

To cut a Github release, follow these steps here: <https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository#creating-a-release>

NOTE: NPM only supports [Semantic Versioning](https://semver.org/) - so ensure your Github release tag and release title follow semantic versioning.
