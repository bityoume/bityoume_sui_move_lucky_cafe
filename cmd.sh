source .env
export GAS_BUDGET=100000000

export BASE_ROUND=`curl -s https://drand.cloudflare.com/52db9ba70e0cc0f6eaf7803dd07447a1f5477735fd3f661792ba94600c84e971/public/latest | jq .round`
echo $BASE_ROUND

sui client switch --address jason
sui client call --function create_cafe --package $PACKAGE_ID --module lucky_cafe--args $BASE_ROUND --gas-budget $GAS_BUDGET --json > output.txt
CAFE=`jq '.objectChanges[] | select((.objectType // "") | test("::lucky_cafe::Cafe$")) | .objectId' -r output.txt`
ADMIN=`jq '.objectChanges[] | select((.objectType // "") | test("::lucky_cafe::Admin$")) | .objectId' -r output.txt`
echo $CAFE
echo $ADMIN

# Alice购买2张+1张Card
sui client switch --address u1
sui client gas --json | jq '.[] | select(.gasBalance > 100000) | .gasCoinId' -r > output.txt
GAS=$(sed -n '1p' output.txt)
SPLIT_COIN=$(sed -n '2p' output.txt)

export COIN=`sui client split-coin --coin-id $SPLIT_COIN --amounts 10 --gas $GAS --gas-budget $GAS_BUDGET --json | jq -r '.objectChanges[] | select(.objectType=="0x2::coin::Coin<0x2::sui::SUI>" and .type=="created") | .objectId'`
echo $COIN
sui client call --function buy_cafe_card --package $PACKAGE_ID --module lucky_cafe --args $CAFE $COIN --gas-budget $GAS_BUDGET 

# Bob购买1张Card
sui client switch --address u2
sui client gas --json | jq '.[] | select(.gasBalance > 100000) | .gasCoinId' -r > output.txt
GAS=$(sed -n '1p' output.txt)
SPLIT_COIN=$(sed -n '2p' output.txt)
sui client split-coin --coin-id $SPLIT_COIN --amounts 5 --gas $GAS --gas-budget $GAS_BUDGET --json > output.txt
jq '.objectChanges[] | select(.objectType=="0x2::coin::Coin<0x2::sui::SUI>" and .type=="created") | .objectId' output.txt | awk '{print "COIN="$1}' > .env2
source .env2
sui client call --function buy_cafe_card --package $PACKAGE_ID --module lucky_cafe --args $CAFE $COIN --gas-budget $GAS_BUDGET 

# Jason使用Card兑换一杯咖啡
export CARD2=0xf548bda49138aca1597fbc8a03e0255f3a68cf6a9f7acdb0786f67c09e2d0e70
sui client switch --address jason
sui client call --function buy_coffee --package $PACKAGE_ID --module lucky_cafe --args $CAFE $CARD2 --gas-budget $GAS_BUDGET 

curl -s https://drand.cloudflare.com/52db9ba70e0cc0f6eaf7803dd07447a1f5477735fd3f661792ba94600c84e971/public/latest > output.txt
export CURRENT_ROUND=`jq '.round' output.txt`
export SIGNATURE=0x`jq -r '.signature' output.txt`

sui client call --function get_lucky_number --package $PACKAGE_ID --module lucky_cafe --args $CAFE $CURRENT_ROUND $SIGNATURE --gas-budget $GAS_BUDGET 

export CARD1=0x825f963b447132c060d66ccbfd91d49da64d2fe630850d31a94c0b14aca58b9b
sui client call --function get_reward_with_lucky_card --package $PACKAGE_ID --module lucky_cafe --args $CAFE $CARD1 --gas-budget $GAS_BUDGET 

sui client call --function remove_lucky_number --package $PACKAGE_ID --module lucky_cafe --args $ADMIN $CAFE --gas-budget $GAS_BUDGET 