# Trillion's Token Design

Trillion's FiatTokenV1 contract is an ERC-20 compatible token. It allows minting/burning of tokens by multiple entities, pausing all activity, freezing of individual addresses, and a way to upgrade the contract so that bugs can be fixed or features added without downtime.

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

The proxy contract is a [`ERC1967Proxy`](https://eips.ethereum.org/EIPS/eip-1967) which gets deployed as part of the `DeployFiatToken.s.sol` script. `FiatToken` is the logic contract which contains the implementation.

To upgrade, use the `UpgradeFiatToken.s.sol` script.

## Roles

The `FiatToken` has a number of roles (addresses) which control different functionality:

* `DEFAULT_ADMIN_ROLE` - acts as the default admin role for all roles. An account with this role will be able to manage any other role.
* `MINTER_ROLE` - can create tokens and destroy tokens (that belong to them)
* `PAUSER_ROLE` - pause the contract, which prevents all transfers, minting, and burning
* `BLACKLISTER_ROLE` - prevent all transfers to or from a particular address, and prevents that address from minting or burning
* `RESCUER_ROLE` - transfer any ERC-20 tokens that are locked up in the contract
* `UPGRADER_ROLE` - manage the proxy-level functionalities such as upgrading the implementation contract

Trillion will control the address of all roles.

We use OpenZeppelin's [Access Control](https://docs.openzeppelin.com/contracts/5.x/access-control#using-access-control) contracts to implement role-based access control. This gives us maximum flexibility flexibility in permissioning based on the principle of least principle (one role per function if needed), and a unified interface to `grantRole`, `revokeRole`, and `renounceRole`.

Only the controller of an account with the `DEFAULT_ADMIN_ROLE` is allowed to grant and revoke roles.

## ERC-20

The `FiatTokenV1` implements the standard methods of the ERC-20 interface with some changes:

* A blacklisted address will be unable to call transfer or transferFrom, and will be unable to receive tokens.
* transfer, transferFrom, and approve will fail if the contract has been paused.

### Creating and Destroying tokens

The FiatTokenV1 contract allows any account with the `MINTER_ROLE` to create and destroy tokens. The controller of these accounts will have to be members of Trillion, and will be vetted by Trillion before they are allowed to create new tokens.

In the future, when we introduce Trillion partners and allow them to assume the `MINTER_ROLE`, we should consider adding a `minterAllowance` that allows Trillion to limit the number of tokens a minter can mint.

### Blacklisting

Addresses can be blacklisted. A blacklisted address will be unable to transfer, mint, or burn tokens.

### Rescuing Tokens

If tokens get sent erroneously to our contract, `FiatToken` supports a `rescue` method that allows us to transfer tokens locked up in the contract to a recipient address.

### Meta transactions compatibility

`FiatToken` implements gasless approval of tokens (standardized as [ERC2612](https://eips.ethereum.org/EIPS/eip-2612)) via the `permit` function.

The `permit` method can be used to change an account’s ERC20 allowance by presenting a message signed by the account. Users may update their ERC-20 allowances by signing a permit message and passing the signed message to a relayer who will execute the on-chain transaction, instead of submitting a transaction themselves. This is in contrast to the `approve/transferFrom` pattern where the token holder account still needs to send the `approve` transaction in order for the allowance to be set.
