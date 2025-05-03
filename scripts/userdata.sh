#!/bin/bash

apt-get update && apt-get -y install tcpdump net-tools
IP=$(ifconfig ens5 | awk '/inet / {print $2}')

# etcd server config
mkdir /root/binaries
cd /root/binaries
wget https://github.com/etcd-io/etcd/releases/download/v3.5.18/etcd-v3.5.18-linux-amd64.tar.gz
tar -xzvf etcd-v3.5.18-linux-amd64.tar.gz
cd /root/binaries/etcd-v3.5.18-linux-amd64/
cp etcd etcdctl /usr/local/bin/

# etcd certificates creation
mkdir /root/certificates
cd /root/certificates

openssl genrsa -out ca.key 2048
openssl req -new -key ca.key -subj "/CN=KUBERNETES-CA" -out ca.csr
openssl x509 -req -in ca.csr -signkey ca.key -out ca.crt -days 1000
openssl genrsa -out etcd.key 2048

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

# integrate systemd with etcd & start running
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

# kube-api server config
cd /root/binaries
wget https://dl.k8s.io/v1.32.1/kubernetes-server-linux-amd64.tar.gz
tar -xzvf kubernetes-server-linux-amd64.tar.gz
cd /root/binaries/kubernetes/server/bin/
cp kube-apiserver kubectl /usr/local/bin/

# api server certificate creation (etcd authentication)
cd /root/certificates

openssl genrsa -out api-etcd.key 2048
openssl req -new -key api-etcd.key -subj "/CN=kube-apiserver" -out api-etcd.csr
openssl x509 -req -in api-etcd.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out api-etcd.crt -days 2000

# service account creation
openssl genrsa -out service-account.key 2048
openssl req -new -key service-account.key -subj "/CN=service-accounts" -out service-account.csr
openssl x509 -req -in service-account.csr -CA ca.crt -CAkey ca.key -CAcreateserial  -out service-account.crt -days 100

# Generate Configuration File for CSR Creation:
cat <<EOF | sudo tee api.conf
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names
[alt_names]
DNS.1 = kubernetes
DNS.2 = kubernetes.default
DNS.3 = kubernetes.default.svc
DNS.4 = kubernetes.default.svc.cluster.local
IP.1 = 127.0.0.1
IP.3 = 10.0.0.1
EOF

# Generate Certificates for API Server
openssl genrsa -out kube-api.key 2048
openssl req -new -key kube-api.key -subj "/CN=kube-apiserver" -out kube-api.csr -config api.conf
openssl x509 -req -in kube-api.csr -CA ca.crt -CAkey ca.key -CAcreateserial  -out kube-api.crt -extensions v3_req -extfile api.conf -days 2000

# Generate Token auth file for static token file authentication
TOKEN_PASSWORD=$(echo $RANDOM | md5sum | head -c 20)
echo "$TOKEN_PASSWORD,dudung,01,admins" > /root/token.csv

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
--tls-cert-file=/root/certificates/kube-api.crt
--tls-private-key-file=/root/certificates/kube-api.key
--token-auth-file=/root/token.csv

[Install]
WantedBy=multi-user.target
EOF

systemctl start kube-apiserver
