#!/bin/bash
CHANNEL_NAME=$2
DOMAIN=$1
ORDERER_TYPE="$3"
P_CN=$(expr $4 - 1)
M_DMIN=$5
echo $DOMAIN
getOrderer() {
  if [ "$ORDERER_TYPE" == "KAFKA" ];then
    echo "KAFKA"
    export ORDERER_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer0.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
    export ORDERER_URL=orderer0.example.com
    else
    echo "NOT KAFKA"
    export ORDERER_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer0.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
    export ORDERER_URL=orderer0.example.com
  fi
  
}

getOrderer
peer channel fetch config config_block.pb -o $ORDERER_URL:7050 -c $CHANNEL_NAME --tls --cafile $ORDERER_CA
which jq
  if [ "$?" -ne 0 ]; then
    echo "Installing jq"
    apt-get -y update && apt-get -y install jq
    else
        echo "$?"
  fi

configtxlator proto_decode --input config_block.pb --type common.Block | jq .data.data[0].payload.data.config > config.json

jq -s '.[0] * {"channel_group":{"groups":{"Application":{"groups": {"'$DOMAIN'MSP":.[1]}}}}}' config.json ./${DOMAIN}.json > modified_config.json

configtxlator proto_encode --input config.json --type common.Config --output config.pb

configtxlator proto_encode --input modified_config.json --type common.Config --output modified_config.pb

configtxlator compute_update --channel_id $CHANNEL_NAME --original config.pb --updated modified_config.pb --output ${DOMAIN}_update.pb

configtxlator proto_decode --input ${DOMAIN}_update.pb --type common.ConfigUpdate | jq . > ${DOMAIN}_update.json

echo '{"payload":{"header":{"channel_header":{"channel_id":"'$CHANNEL_NAME'", "type":2}},"data":{"config_update":'$(cat ${DOMAIN}_update.json)'}}}' | jq . > ${DOMAIN}_update_in_envelope.json

configtxlator proto_encode --input ${DOMAIN}_update_in_envelope.json --type common.Envelope --output ${DOMAIN}_update_in_envelope.pb
peer=0
while [ "$peer" != "$P_CN" ]
do
    export CORE_PEER_ADDRESS=peer$peer.${M_DMIN}.example.com:7051
    peer channel signconfigtx -f ${DOMAIN}_update_in_envelope.pb
    peer=$(expr $peer + 1)
done
export CORE_PEER_ADDRESS=peer0.${M_DMIN}.example.com:7051