#!/bin/bash

# Check for arguments
if [ -z "$1" ] || [ -z "$2" ] ; then
  echo "Usage: npm run deploy -- <token> <chain>"
  # Example:
  # npm run deploy -- tnusd eth-mainnet
  # npm run deploy -- tnsgd eth-sepolia
  # npm run deploy -- tnusd op-mainnet
  # npm run deploy -- tnusd op-sepolia
  exit 1
fi

# Assign arguments to variables
TOKEN=$1
CHAIN=$2
ENV_FILE="config/${TOKEN}/${CHAIN}.env"
ROOT_ENV_FILE="./.env"

# Load environment variables from .env file
if [ -f "$ENV_FILE" ]; then
  source $ENV_FILE

  # Copy the .env file to the current directory
  cp "$ENV_FILE" "$ROOT_ENV_FILE"

  # Confirm the copy was successful
  if [[ -f "$ROOT_ENV_FILE" ]]; then
      echo "File '.env' has been successfully copied to the current folder."
  else
      echo "Error: Failed to copy '.env' to the current folder."
  fi
else
  echo "$ENV_FILE file not found!"
  exit 1
fi

if [[ -n "${ETHERSCAN_API_KEY}" ]]; then
  # with verify
  forge script script/UpgradeFiatToken.s.sol:UpgradeFiatToken --rpc-url $RPC_URL --ledger --hd-paths $DERIVATION_PATH --sender $DEFAULT_ADMIN_ADDRESS --broadcast --verify --ffi -vvvv
else
  # no verify
  forge script script/UpgradeFiatToken.s.sol:UpgradeFiatToken --rpc-url $RPC_URL --ledger --hd-paths $DERIVATION_PATH --sender $DEFAULT_ADMIN_ADDRESS --broadcast --ffi -vvvv
fi
