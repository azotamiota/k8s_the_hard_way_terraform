#!/bin/bash

apt-get update && apt-get -y install tcpdump net-tools
IP=$(ifconfig ens5 | awk '/inet / {print $2}')

./scripts/etcd_config.sh
./scripts/kube-apiserver_config.sh