# PRINT EVERY COMMAND
set -ux

if [ ! -d "$(pwd)/.oraid2" ]; then
    apk add curl

    moniker=${MONIKER:-"NODE_SYNC"}

    # make orai state sync directories

    SEED=e18f82a6da3a9842fa55769955d694f62f7f48bd@seed1.orai.zone:26656,893f246ffdffae0a9ef127941379303531f50d5c@seed2.orai.zone:26656,4fa7895fc43f618b53cd314585b421ee47b75639@seed3.orai.zone:26656,defeea41a01b5afdb79ef2af155866e122797a9c@seed4.orai.zone:26656
    SNAP_IP4=${SNAP_IP3:-"rpc.orai.mortysnode.nl"}
    SNAP_IP3=${SNAP_IP3:-"statesync3.orai.zone"}
    SNAP_IP2=${SNAP_IP2:-"statesync2.orai.zone"}
    SNAP_IP1=${SNAP_IP1:-"statesync1.orai.zone"}
    CHAIN_ID="Oraichain"
    TRUST_HEIGHT_RANGE=${TRUST_HEIGHT_RANGE:-200}

    PEER_RPC_PORT=26657
    PEER_P2P_PORT=26656

    SNAP_RPC4=https://$SNAP_IP4
    SNAP_RPC3=http://$SNAP_IP3:$PEER_RPC_PORT
    SNAP_RPC2=http://$SNAP_IP2:$PEER_RPC_PORT
    SNAP_RPC1=http://$SNAP_IP1:$PEER_RPC_PORT

    PEER_ID4=$(curl --no-progress-meter $SNAP_RPC4/status | jq -r '.result.node_info.id')
    PEER_ID3=$(curl --no-progress-meter $SNAP_RPC3/status | jq -r '.result.node_info.id')
    PEER_ID2=$(curl --no-progress-meter $SNAP_RPC2/status | jq -r '.result.node_info.id')
    PEER_ID1=$(curl --no-progress-meter $SNAP_RPC1/status | jq -r '.result.node_info.id')

    echo "peer id 4: $PEER_ID4"
    echo "peer id 3: $PEER_ID3"
    echo "peer id 2: $PEER_ID2"
    echo "peer id 1: $PEER_ID1"

    # MAKE HOME FOLDER AND GET GENESIS

    # reset the node
    oraid tendermint unsafe-reset-all --home=.oraid

    # change config.toml values
    STATESYNC_CONFIG=.oraid/config/config.toml

    # state sync node
    #sed -i -E 's|tcp://127.0.0.1:26657|tcp://0.0.0.0:26657|g' $STATESYNC_CONFIG

    # Change config files (set the node name, add persistent peers, set indexer = "null")
    #sed -i -e "s%^moniker *=.*%moniker = \"$moniker\"%; " $STATESYNC_CONFIG
    # sed -i -e "s%^indexer *=.*%indexer = \"null\"%; " $STATESYNC_CONFIG

    # GET TRUST HASH AND TRUST HEIGHT
    LATEST_HEIGHT=$(curl -s $SNAP_RPC2/block | jq -r .result.block.header.height); \
    BLOCK_HEIGHT=$((LATEST_HEIGHT - $TRUST_HEIGHT_RANGE)); \
    TRUST_HASH=$(curl -s "$SNAP_RPC2/block?height=$BLOCK_HEIGHT" | jq -r .result.block_id.hash)

    # TELL USER WHAT WE ARE DOING
    echo "LATEST HEIGHT: $LATEST_HEIGHT"
    echo "TRUST HEIGHT: $BLOCK_HEIGHT"
    echo "TRUST HASH: $TRUST_HASH"

    sed -i.bak -E "s|^(enable[[:space:]]+=[[:space:]]+).*$|\1true| ; \

    s|^(allow_duplicate_ip[[:space:]]+=[[:space:]]+).*$|\1true| ; \

    s|^(addr_book_strict[[:space:]]+=[[:space:]]+).*$|\1false| ; \

    s|^(rpc_servers[[:space:]]+=[[:space:]]+).*$|\1\"$SNAP_RPC1,$SNAP_RPC2,$SNAP_RPC3,$SNAP_RPC4\"| ; \

    s|^(trust_height[[:space:]]+=[[:space:]]+).*$|\1$BLOCK_HEIGHT| ; \

    s|^(trust_hash[[:space:]]+=[[:space:]]+).*$|\1\"$TRUST_HASH\"| ; \

    s|^(seeds[[:space:]]+=[[:space:]]+).*$|\1\"$SEED\"|" $STATESYNC_CONFIG

    echo "Waiting 1 seconds to start state sync"
    sleep 1
fi


# THERE, NOW IT'S SYNCED AND YOU CAN PLAY
cosmovisor run start --home=.oraid --minimum-gas-prices=0.001orai
