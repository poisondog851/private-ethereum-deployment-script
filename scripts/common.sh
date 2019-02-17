#!/bin/bash


ip_address() {
    IP_ADDRESS=$(hostname -I | xargs)
    if [[ $(echo ${IP_ADDRESS} | wc -w) > 1 ]]
    then
        echo "Более одного подходящего IP адреса: ${IP_ADDRESS}"
        IP_ADDRESS=$(echo ${IP_ADDRESS} | awk '{print $`}')
        echo "Использую адрес ${IP_ADDRESS}"
    fi
    echo ${IP_ADDRESS}
}


#определяем путь к geth. Ожидаем найти директорию, которая начинается с паттерна 'geth'
define_geth() {
    GETH_DIR=$(find ${1} -maxdepth 1 -name 'geth*')
    candidates=$(echo "$GETH_DIR" | wc -w)
    if [[ ${candidates}  == 0 ]]
    then
        echo "Не удалось найти директорию с бинарным файлом geth: ${1}"
        exit 1
    elif [[ ${candidates} > 1 ]]
    then
        echo "Более одного кандидата для директории с бинарным файлом geth: ${1}"
        exit 1
    fi
    echo ${GETH_DIR}
}

