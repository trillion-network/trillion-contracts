-include .env

# Deploy contracts
deploy :; @forge script script/Deploy.s.sol:Deploy --rpc-url ${RPC_URL} --broadcast --verify --etherscan-api-key ${ETHERSCAN_API_KEY}  -vvvv
