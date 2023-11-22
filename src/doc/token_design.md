# Trillion's Token Design

Trillion's FiatToken contract is an ERC-20 compatible token. It allows minting/burning of tokens by multiple entities, pausing all activity, freezing of individual addresses, and a way to upgrade the contract so that bugs can be fixed or features added without downtime.

## Upgradeability

Trillion uses the [UUPS](https://eips.ethereum.org/EIPS/eip-1822) Proxy Upgrade Pattern. The basic idea is that in order to allow upgrades on smart contracts that are by design immutable after deployment, we introduce a proxy contract that can execute functions on a logic contract using the `delegatecall()` function. This allows us to keep the deployed contract (proxy) the same, while its implementation (logic) can be upgraded. For more information about this pattern, refer to this [guide](https://docs.openzeppelin.com/upgrades-plugins/1.x/proxies).

```
User ---- tx ---> Proxy ----------> Implementation_v0
                     |
                      ------------> Implementation_v1
                     |
                      ------------> Implementation_v2
```

We use OpenZeppelin's [Upgrades Plugin](https://github.com/OpenZeppelin/openzeppelin-foundry-upgrades) to deploy our contracts, which runs upgrade safety checks by default during deployments and upgrades.

The proxy contract is a [`ERC1967Proxy`](https://eips.ethereum.org/EIPS/eip-1967) which gets deployed as part of the `Deploy.s.sol` script. `FiatToken` is the logic contract which contains the implementation.

## Roles

The `FiatToken` has a number of roles (addresses) which control different functionality:

* `DEFAULT_ADMIN_ROLE` - acts as the default admin role for all roles. An account with this role will be able to manage any other role.
* `MINTER_ROLE` - can create tokens (and destroy, unless we add a `BURNER_ROLE`)
* `PAUSER_ROLE` - pause the contract, which prevents all transfers, minting, and burning
* `BLACKLISTER_ROLE` - prevent all transfers to or from a particular address, and prevents that address from minting or burning
* `RESCUER_ROLE` - transfer any ERC-20 tokens that are locked up in the contract
* `UPGRADER_ROLE` - manage the proxy-level functionalities such as upgrading the implementation contract
* `OWNER` - re-assign any of the roles except for admin

Trillion will control the address of all roles.

## ERC-20

The `FiatToken` implements the standard methods of the ERC-20 interface with some changes:

* A blacklisted address will be unable to call transfer or transferFrom, and will be unable to receive tokens.
* transfer, transferFrom, and approve will fail if the contract has been paused.
