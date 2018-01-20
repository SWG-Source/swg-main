#!/bin/bash

NODE_COUNT=

echo 'Generating node list...'


if [ ! -d ./exe/ ]; then
	mkdir ./exe/
	mkdir ./exe/linux
fi

read -p "How many nodes are in this cluster? " NODE_COUNT

echo "[TaskManager]" > ./exe/linux/nodes.cfg

# For each node, prompt for an ip.
for i in $(seq 0 $(expr $NODE_COUNT - 1))
do
	read -p "node$i ip: (Try using what is specified for your hostname in /etc/hosts " CURRENT_NODE_IP
	echo "node$i=$CURRENT_NODE_IP" >> ./exe/linux/nodes.cfg
done

