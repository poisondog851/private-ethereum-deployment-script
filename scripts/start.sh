#!/bin/bash

. ./common.sh

VERBOSE=true
RPC_PORT=8545

while [[ -n "$1" ]]
do
	case "$1" in
		-s) VERBOSE=false;;
		-r) RPC_PORT=$2
		    shift;;
		*) echo -e " keys:\n -r --> rpc port number\n -s --> silent"
			exit
	esac
	shift
done

if [[ ${VERBOSE} == false ]]
then
	exec &> /dev/null
fi

WORK_DIR=$(readlink -e `dirname $0`/../)

cd ${WORK_DIR}/eth-netstats
WS_SECRET=secret nohup npm start &
cd -

sleep 1

ip_address

define_geth ${WORK_DIR}

NODE_COUNT=$(cat ${WORK_DIR}/properties | grep NODE_COUNT | awk -F "=" '{print $2}')
ACCOUNTS_COUNT=$(cat ${WORK_DIR}/properties | grep ACCOUNTS_COUNT | awk -F "=" '{print $2}')
BLOCK_TIME=$(cat ${WORK_DIR}/properties | grep BLOCK_TIME | awk -F "=" '{print $2}')
PORT=$(cat ${WORK_DIR}/properties | grep PORT | awk -F "=" '{print $2}')

echo NODE_COUNT ${NODE_COUNT}
echo ACCOUNTS_COUNT ${ACCOUNTS_COUNT}
echo BLOCK_TIME ${BLOCK_TIME}
echo PORT ${PORT}

for (( i = 0; i < ${NODE_COUNT}; i++ ))
do
    line=$((${i} * (${ACCOUNTS_COUNT} + 1) + 1))
    coinbase=$(sed -n "s/0x//;${line}p" ${WORK_DIR}/addresses)
	${GETH_DIR}/geth --datadir ${WORK_DIR}/node-${i} --mine --rpccorsdomain "*" --rpcapi eth,net,web3,personal --ethstats node-${i}:secret@${IP_ADDRESS}:3000 --rpcport ${RPC_PORT} --port ${PORT} --password ${WORK_DIR}/password_file --rpc --nodiscover --unlock 0x${coinbase} &
	sleep 3
	${GETH_DIR}/geth --exec "loadScript('${WORK_DIR}/scripts/cmd.js')" attach ${WORK_DIR}/node-${i}/geth.ipc
	PORT=$((${PORT}+1))
	RPC_PORT=$((${RPC_PORT}+1))
	if [[ ! -f ${WORK_DIR}/.lock ]]
	then
		touch ${WORK_DIR}/.lock
		sleep $((${BLOCK_TIME} * 3))
	fi
done

