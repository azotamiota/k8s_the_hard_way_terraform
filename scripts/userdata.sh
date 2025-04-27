#!/bin/bash

IP=$(ifconfig ens5 | awk '/inet / {print $2}')

./etcd_config.sh
./kube-apiserver_config.sh