#!/bin/bash

# ETCD server & certificates creation
apt-get update && apt-get -y install tcpdump net-tools
mkdir /root/binaries
cd /root/binaries
wget https://github.com/etcd-io/etcd/releases/download/v3.5.18/etcd-v3.5.18-linux-amd64.tar.gz
tar -xzvf etcd-v3.5.18-linux-amd64.tar.gz
cd /root/binaries/etcd-v3.5.18-linux-amd64/
cp etcd etcdctl /usr/local/bin/

mkdir /root/certificates
cd /root/certificates

openssl genrsa -out ca.key 2048
openssl req -new -key ca.key -subj "/CN=KUBERNETES-CA" -out ca.csr
openssl x509 -req -in ca.csr -signkey ca.key -out ca.crt -days 1000

openssl genrsa -out etcd.key 2048
IP=$(ifconfig ens5 | awk '/inet / {print $2}')

cat > etcd.cnf <<EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names
[alt_names]
IP.1 = ${IP}
IP.2 = 127.0.0.1
EOF

openssl req -new -key etcd.key -subj "/CN=etcd" -out etcd.csr -config etcd.cnf
openssl x509 -req -in etcd.csr -CA ca.crt -CAkey ca.key -CAcreateserial  -out etcd.crt -extensions v3_req -extfile etcd.cnf -days 2000

openssl genrsa -out dudung.key 2048
openssl req -new -key dudung.key -subj "/CN=dudung" -out dudung.csr
openssl x509 -req -in dudung.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out dudung.crt -extensions v3_req  -days 2000

# create systemd & start etcd running
mkdir /var/lib/etcd
chmod 700 /var/lib/etcd

cat <<EOF | sudo tee /etc/systemd/system/etcd.service
[Unit]
Description=etcd
Documentation=https://github.com/coreos

[Service]
ExecStart=/usr/local/bin/etcd \\
  --cert-file=/root/certificates/etcd.crt \\
  --key-file=/root/certificates/etcd.key \\
  --trusted-ca-file=/root/certificates/ca.crt \\
  --client-cert-auth \\
  --listen-client-urls https://127.0.0.1:2379 \\
  --advertise-client-urls https://127.0.0.1:2379 \\
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl start etcd
systemctl enable etcd