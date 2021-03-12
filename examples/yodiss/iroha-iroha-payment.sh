#!/bin/bash

export IROHA0='localhost:50051'
export IROHA1='localhost:50052'

export SRC_ACCOUNT_INTERLEDGER='alice'
export MID_ACCOUNT_INTERLEDGER='bob'
export DST_ACCOUNT_INTERLEDGER='charlie'

export SRC_ACCOUNT="${SRC_ACCOUNT_INTERLEDGER}@test"
export MID_ACCOUNT="${MID_ACCOUNT_INTERLEDGER}@test"
export DST_ACCOUNT="${DST_ACCOUNT_INTERLEDGER}@test"

export SRC_ACCOUNT_AUTH_INTERLEDGER='in_alice'
export MID_ACCOUNT_AUTH_INTERLEDGER='bob_password'
export DST_ACCOUNT_AUTH_INTERLEDGER='charlie_password'

export SRC_ACCOUNT_AUTH_NODE='alice_auth_token'

export SRC_COIN='coin0#test'
export DST_COIN='coin1#test'

export NETWORK_PREFIX='yodiss'
export NETWORK="${NETWORK_PREFIX}_ilp-network"

export SETTLE_THRESHOLD=500  # wartosc ponizej ktorej nie dokonywany jest przelew


function addAssets
{
  initial_account_balance=1000

  printf "Sending transaction for depositing assets into ${SRC_ACCOUNT_INTERLEDGER}'s Iroha0 account...\n"
  ./iroha-add-asset-quantity.py "${IROHA0}" "${SRC_ACCOUNT}" "./iroha0-data/${SRC_ACCOUNT}.priv" "${SRC_COIN}" "${initial_account_balance}"

  printf "Sending transaction for depositing assets into ${MID_ACCOUNT_INTERLEDGER}'s Iroha1 account...\n"
  ./iroha-add-asset-quantity.py "${IROHA1}" "${MID_ACCOUNT}" "./iroha1-data/${MID_ACCOUNT}.priv" "${DST_COIN}" "${initial_account_balance}"
}

function checkBalances
{
  printf "Checking ${SRC_ACCOUNT_INTERLEDGER}'s Iroha0 balances...\n"
  ./iroha-check-balances.py "${IROHA0}" "${SRC_ACCOUNT}" "./iroha0-data/${SRC_ACCOUNT}.priv" "${SRC_ACCOUNT}"

  printf "Checking ${MID_ACCOUNT_INTERLEDGER}'s Iroha0 balances...\n"
  ./iroha-check-balances.py "${IROHA0}" "${SRC_ACCOUNT}" "./iroha0-data/${SRC_ACCOUNT}.priv" "${MID_ACCOUNT}"

  printf "Checking ${MID_ACCOUNT_INTERLEDGER}'s Iroha1 balances...\n"
  ./iroha-check-balances.py "${IROHA1}" "${MID_ACCOUNT}" "./iroha1-data/${MID_ACCOUNT}.priv" "${MID_ACCOUNT}"

  printf "Checking ${DST_ACCOUNT_INTERLEDGER}'s Iroha1 balances...\n"
  ./iroha-check-balances.py "${IROHA1}" "${MID_ACCOUNT}" "./iroha1-data/${MID_ACCOUNT}.priv" "${DST_ACCOUNT}"
}


function setUpAccounts
{
  export ILP_ADDRESS_PREFIX='example'

  printf "Adding ${SRC_ACCOUNT_INTERLEDGER}'s account...\n"

  docker run --rm --network ${NETWORK} interledgerrs/ilp-cli:latest \
      --node http://alice-node:7770 accounts create "${SRC_ACCOUNT_INTERLEDGER}" \
      --auth "${SRC_ACCOUNT_AUTH_NODE}" \
      --ilp-address ${ILP_ADDRESS_PREFIX}.${SRC_ACCOUNT_INTERLEDGER} \
      --asset-code "${SRC_COIN}" \
      --asset-scale 2 \
      --max-packet-amount 100 \
      --ilp-over-http-incoming-token "${SRC_ACCOUNT_AUTH_INTERLEDGER}" \
      --settle-to 0

  # This will trigger a settlement engine setup account action on Alice's side
  printf "Adding ${MID_ACCOUNT_INTERLEDGER}'s account on ${SRC_ACCOUNT_INTERLEDGER}'s node...\n"
  docker run --rm --network ${NETWORK} interledgerrs/ilp-cli:latest \
      --node http://alice-node:7770 accounts create ${MID_ACCOUNT_INTERLEDGER} \
      --auth "${SRC_ACCOUNT_AUTH_NODE}" \
      --ilp-address ${ILP_ADDRESS_PREFIX}.${MID_ACCOUNT_INTERLEDGER} \
      --asset-code "${SRC_COIN}" \
      --asset-scale 2 \
      --max-packet-amount 100 \
      --settlement-engine-url http://alice-settlement:3000 \
      --ilp-over-http-incoming-token "${MID_ACCOUNT_AUTH_INTERLEDGER}" \
      --ilp-over-http-outgoing-token alice_password \
      --ilp-over-http-url http://bob-node:8770/accounts/alice/ilp \
      --settle-threshold "${SETTLE_THRESHOLD}" \
      --min-balance -1000 \
      --settle-to 0 \
      --routing-relation Peer &

  # This will trigger a settlement engine setup account action on Bob's side
  printf "Adding ${SRC_ACCOUNT_INTERLEDGER}'s account on ${MID_ACCOUNT_INTERLEDGER}'s node...\n"
  docker run --rm --network ${NETWORK} interledgerrs/ilp-cli:latest \
      --node http://bob-node:8770 accounts create ${SRC_ACCOUNT_INTERLEDGER} \
      --auth bob_auth_token \
      --ilp-address ${ILP_ADDRESS_PREFIX}.${SRC_ACCOUNT_INTERLEDGER} \
      --asset-code "${SRC_COIN}" \
      --asset-scale 2 \
      --max-packet-amount 100 \
      --settlement-engine-url http://bob-settlement-0:3001 \
      --ilp-over-http-incoming-token alice_password \
      --ilp-over-http-outgoing-token "${MID_ACCOUNT_AUTH_INTERLEDGER}" \
      --ilp-over-http-url http://alice-node:7770/accounts/bob/ilp \
      --settle-threshold "${SETTLE_THRESHOLD}" \
      --min-balance -1000 \
      --settle-to 0 \
      --routing-relation Peer

  # This will trigger a settlement engine setup account action on Bob's side
  printf "Adding ${DST_ACCOUNT_INTERLEDGER}'s account on ${MID_ACCOUNT_INTERLEDGER}'s node...\n"
  docker run --rm --network ${NETWORK} interledgerrs/ilp-cli:latest \
      --node http://bob-node:8770 accounts create ${DST_ACCOUNT_INTERLEDGER} \
      --auth bob_auth_token \
      --asset-code "${DST_COIN}" \
      --asset-scale 2 \
      --settlement-engine-url http://bob-settlement-1:3002 \
      --ilp-over-http-incoming-token "${DST_ACCOUNT_AUTH_INTERLEDGER}" \
      --ilp-over-http-outgoing-token bob_other_password \
      --ilp-over-http-url http://charlie-node:9770/accounts/bob/ilp \
      --settle-threshold "${SETTLE_THRESHOLD}" \
      --min-balance -1000 \
      --settle-to 0 \
      --routing-relation Child

  printf "Adding ${DST_ACCOUNT_INTERLEDGER}'s account...\n"
  docker run --rm --network ${NETWORK} interledgerrs/ilp-cli:latest \
      --node http://charlie-node:9770 accounts create ${DST_ACCOUNT_INTERLEDGER} \
      --auth charlie_auth_token \
      --asset-code "${DST_COIN}" \
      --asset-scale 2 \
      --ilp-over-http-incoming-token in_charlie \
      --settle-to 0

  # This will trigger a settlement engine setup account action on Charlie's side
  printf "Adding ${MID_ACCOUNT_INTERLEDGER}'s account on ${DST_ACCOUNT_INTERLEDGER}'s node...\n"
  docker run --rm --network ${NETWORK} interledgerrs/ilp-cli:latest \
      --node http://charlie-node:9770 accounts create ${MID_ACCOUNT_INTERLEDGER} \
      --auth charlie_auth_token \
      --ilp-address ${ILP_ADDRESS_PREFIX}.${MID_ACCOUNT_INTERLEDGER} \
      --asset-code "${DST_COIN}" \
      --asset-scale 2 \
      --settlement-engine-url http://charlie-settlement:3003 \
      --ilp-over-http-incoming-token bob_other_password \
      --ilp-over-http-outgoing-token "${DST_ACCOUNT_AUTH_INTERLEDGER}" \
      --ilp-over-http-url http://bob-node:8770/accounts/charlie/ilp \
      --settle-threshold "${SETTLE_THRESHOLD}" \
      --min-balance -1000 \
      --settle-to 0 \
      --routing-relation Parent
}

function informConnectorsAboutExchangeRates
{
  SRC_COIN_UPPER=$(echo "$SRC_COIN" | awk '{ print toupper($0) }')
  DST_COIN_UPPER=$(echo "$DST_COIN" | awk '{ print toupper($0) }')

  # All connectors must be aware of the exchange rate of the assets being exchanged
  printf "Informing connectors about the exchange rates...\n"

  curl --silent --output /dev/null --show-error \
      -X PUT -H "Authorization: Bearer ${SRC_ACCOUNT_AUTH_NODE}" \
      -d "{\"${SRC_COIN_UPPER}\": 1, \"${DST_COIN_UPPER}\": 1}" \
      http://localhost:7770/rates

  curl --silent --output /dev/null --show-error \
      -X PUT -H 'Authorization: Bearer bob_auth_token' \
      -d "{\"${SRC_COIN_UPPER}\": 1, \"${DST_COIN_UPPER}\": 1}" \
      http://localhost:8770/rates

  curl --silent --output /dev/null --show-error \
      -X PUT -H 'Authorization: Bearer charlie_auth_token' \
      -d "{\"${SRC_COIN_UPPER}\": 1, \"${DST_COIN_UPPER}\": 1}" \
      http://localhost:9770/rates
}

function interLedgerTransfer
{
  amount_to_transfer=500
  if [ $# -gt 0 ] ; then
        amount_to_transfer=$1
  fi

  printf "Sending a payment from ${SRC_ACCOUNT_INTERLEDGER} to ${DST_ACCOUNT_INTERLEDGER}: ${amount_to_transfer} of ${SRC_COIN}...\n"
  docker run --rm --network ${NETWORK} interledgerrs/ilp-cli:latest \
      --node http://alice-node:7770 pay ${SRC_ACCOUNT_INTERLEDGER} \
      --auth "${SRC_ACCOUNT_AUTH_INTERLEDGER}" \
      --amount ${amount_to_transfer} \
      --to http://charlie-node:9770/accounts/${DST_ACCOUNT_INTERLEDGER}/spsp
}


function main
{
  addAssets

  checkBalances
  setUpAccounts

  sleep 10


  informConnectorsAboutExchangeRates

  sleep 3

  interLedgerTransfer

  sleep 10

  checkBalances
}


if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
