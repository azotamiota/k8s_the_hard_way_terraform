#!/bin/bash

apt-get update && apt-get install net-tools
mkdir /root/binaries
cd /root/binaries
wget https://github.com/etcd-io/etcd/releases/download/v3.5.18/etcd-v3.5.18-linux-amd64.tar.gz
tar -xzvf etcd-v3.5.18-linux-amd64.tar.gz
cd /root/binaries/etcd-v3.5.18-linux-amd64/
cp etcd etcdctl /usr/local/bin/
cd /tmp
