#!/bin/bash

sui move build
sui client publish --gas-budget 100000000 --force --json > sui-build.json

> .env
jq '.objectChanges[] | select(.objectType=="0x2::package::UpgradeCap") | .objectId' sui-build.json | awk '{print "ORIGINAL_UPGRADE_CAP_ID="$1}' >> .env
jq '.objectChanges[].packageId | select( . != null )' sui-build.json | awk '{print "PACKAGE_ID="$1}' >> .env
sui client gas --json | jq '.[-1].gasCoinId' | awk '{printf "SUI_FEE_COIN_ID=%s\n",$1}' >> .env
sui client switch --address jason
sui client active-address | awk '{printf "JASON=\"%s\"\n",$1}' >> .env
sui client switch --address u1
sui client active-address | awk '{printf "ALICE=\"%s\"\n",$1}' >> .env
sui client switch --address u2
sui client active-address | awk '{printf "BOB=\"%s\"\n",$1}' >> .env
cat .env
source .env