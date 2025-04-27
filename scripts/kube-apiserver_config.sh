#!/bin/bash

# kube-api server config
cd /root/binaries
wget https://dl.k8s.io/v1.32.1/kubernetes-server-linux-amd64.tar.gz
tar -xzvf kubernetes-server-linux-amd64.tar.gz
cd /root/binaries/kubernetes/server/bin/
cp kube-apiserver kubectl /usr/local/bin/

# api server certificate creation
cd /root/certificates

openssl genrsa -out api-etcd.key 2048
openssl req -new -key api-etcd.key -subj "/CN=kube-apiserver" -out api-etcd.csr
openssl x509 -req -in api-etcd.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out api-etcd.crt -days 2000

# service account creation
openssl genrsa -out service-account.key 2048
openssl req -new -key service-account.key -subj "/CN=service-accounts" -out service-account.csr
openssl x509 -req -in service-account.csr -CA ca.crt -CAkey ca.key -CAcreateserial  -out service-account.crt -days 100

# integrate systemd with api server
cat <<EOF | sudo tee /etc/systemd/system/kube-apiserver.service
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-apiserver \
--advertise-address=${IP} \
--etcd-cafile=/root/certificates/ca.crt \
--etcd-certfile=/root/certificates/api-etcd.crt \
--etcd-keyfile=/root/certificates/api-etcd.key \
--etcd-servers=https://127.0.0.1:2379 \
--service-account-key-file=/root/certificates/service-account.crt \
--service-cluster-ip-range=10.0.0.0/24 \
--service-account-signing-key-file=/root/certificates/service-account.key \
--service-account-issuer=https://127.0.0.1:6443 

[Install]
WantedBy=multi-user.target
EOF

systemctl start kube-apiserver
