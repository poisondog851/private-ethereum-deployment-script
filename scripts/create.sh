#!/bin/bash

#TODO сделать создание аккаунтов параллельным

. ./common.sh

#количество нод
NODE_COUNT=3

#Количество акаунтов на каждой ноде
ACCOUNTS_COUNT=1

#время формирования одного блока
BLOCK_TIME=3

#номер порта
PORT=30310

while [[ -n "$1" ]]
do
	case "$1" in
		-bt)
			BLOCK_TIME=$2
			shift ;;
		-p)
			PORT=$2
			shift ;;
		-n)
			NODE_COUNT=$2
			shift ;;
		-a)
			ACCOUNTS_COUNT=$2
			shift ;;
		*) echo -e " keys:\n -p  --> port number\n -bt --> block time\n -n  --> nodes count\n -a --> accounts count on each node"
			exit
	esac
	shift
done

#проверяем, что установлен bootnode
if [[ $(hash bootnode > /dev/null 2>&1 ; echo $?) != '0' ]]
then
    echo "Для продолжения установите bootnode"
    exit 1
fi

WORK_DIR=$(readlink -e `dirname $0`/../)
define_geth ${WORK_DIR}

#если нет папки с мониторингом, то клонируем его
if ! [[ -d ${WORK_DIR}/eth-netstats ]]
then
	echo "Устанавливаю мониторинг блокчейна"
	#проверяем, что установлен npm
	if [[ $(npm -v > /dev/null 2>&1 ; echo $?) != '0' ]]
	then
        echo "Для продолжения установите npm"
		exit 1
	fi

	git clone https://github.com/cubedro/eth-netstats ${WORK_DIR}/eth-netstats
	cd ${WORK_DIR}/eth-netstats
	sudo npm install
	sudo npm install -g grunt-cli
	grunt
	cd -
	echo "Мониторинг блокчейна установлен"
fi

#создаем ноды
ADDRESSES=${WORK_DIR}/addresses

#если файл адрес существует, чистим его
if [[ -e ${ADDRESSES} ]]
then
	> ${ADDRESSES}
fi

rm -f ${WORK_DIR}/.lock

#если папки node-*существуют, удаляем их
find -O0 ${WORK_DIR} -name "node-*"  |  xargs rm -r > /dev/null 2>&1

#файл, откуда читаем пароль
touch ${WORK_DIR}/password_file


for (( i=0; i < $NODE_COUNT; i++ ))
do
    for((z = 0; z < ${ACCOUNTS_COUNT}; z++))
    do
        address=$(${GETH_DIR}/geth account new --datadir ${WORK_DIR}/node-${i} --password ${WORK_DIR}/password_file)
        echo ${address} | awk -v p="0x" '{print p $2}' | tr -d '{}'| tee -a ${ADDRESSES}
	done
	echo >> ${ADDRESSES}
done


echo "Создаю генезис блок"
GENESIS_FILE=${WORK_DIR}/genesis.json


echo -e "{
  \"config\": {
    \"chainId\": 77,
    \"homesteadBlock\": 1,
    \"eip150Block\": 2,
    \"eip150Hash\": \"0x0000000000000000000000000000000000000000000000000000000000000000\",
    \"eip155Block\": 3,
    \"eip158Block\": 3,
    \"byzantiumBlock\": 4,
    \"clique\": {
      \"period\": ${BLOCK_TIME},
      \"epoch\": 30000
    }
  },
  \"nonce\": \"0x0\",
  \"timestamp\": \"0x5a634637\",
  \"extraData\": "> ${GENESIS_FILE}

EXTRA_DATA=0x0000000000000000000000000000000000000000000000000000000000000000
for (( i = 0; i < ${NODE_COUNT}; i++ ))
do
    line=$((${i} * (${ACCOUNTS_COUNT} + 1) + 1))
    coinbase=$(sed -n "s/0x//;${line}p" ${ADDRESSES})
	EXTRA_DATA+=${coinbase}
done
EXTRA_DATA+=0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
echo "\"$EXTRA_DATA\"," >> ${GENESIS_FILE}

echo -e "
  \"gasLimit\": \"0x47E7C4\",
  \"difficulty\": \"0x1\",
  \"mixHash\": \"0x0000000000000000000000000000000000000000000000000000000000000000\",
  \"coinbase\": \"0x0000000000000000000000000000000000000000\",
  \"alloc\": {" >> ${GENESIS_FILE}


for (( i = 0; i < ${NODE_COUNT}; i++ ))
do
    line=$((${i} * (${ACCOUNTS_COUNT} + 1) + 1))
    coinbase=$(sed -n "s/0x//;${line}p" ${ADDRESSES})
    echo -e "\t\"${coinbase}\": {
          \t\"balance\": \"0x200000000000000000000000000000000000000000000000000000000000000\"
        },"
done >> ${GENESIS_FILE}

sed -i '$ s/,$//' ${GENESIS_FILE}
echo -e "  },
  \"number\": \"0x0\",
  \"gasUsed\": \"0x0\",
  \"parentHash\": \"0x0000000000000000000000000000000000000000000000000000000000000000\"
}" >>  ${GENESIS_FILE}

echo "Закончил создание генезис блока"

echo "Инициализирую генезис блок"
for((i=0; i < ${NODE_COUNT}; i++))
do
	${GETH_DIR}/geth init ${WORK_DIR}/genesis.json --datadir ${WORK_DIR}/node-${i}
done
echo "Закончил инициализацию генезис блок"


echo "Создаю static-nodes.json"
ip_address

STATIC_NODES=${WORK_DIR}/static-nodes.json

echo  -e "[" > ${STATIC_NODES}


for((i=0; i < ${NODE_COUNT}; i++))
do
	bootnode -genkey ${WORK_DIR}/node-${i}/geth/nodekey
	node_id=$(bootnode -nodekey ${WORK_DIR}/node-${i}/geth/nodekey -writeaddress)
	node_url=\"enode://${node_id}@${IP_ADDRESS}:${PORT}\",
	echo ${node_url}
	PORT=$((PORT+1))
done >> ${STATIC_NODES}

sed -i '$ s/,$//' ${STATIC_NODES}

echo  -e "]" >> ${STATIC_NODES}

for((i=0; i < ${NODE_COUNT}; i++))
do
	cp ${STATIC_NODES} ${WORK_DIR}/node-${i}/geth/
done

echo "Создал static-nodes.json"

#записываем проперти
echo -e "NODE_COUNT=${NODE_COUNT}
ACCOUNTS_COUNT=${ACCOUNTS_COUNT}
BLOCK_TIME=${BLOCK_TIME}
PORT=$((${PORT} - ${NODE_COUNT}))" > ${WORK_DIR}/properties

