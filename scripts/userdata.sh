#!/bin/bash

apt-get update && apt-get -y install net-tools
IP=$(ifconfig ens5 | awk '/inet / {print $2}')

# etcd server config
mkdir /root/binaries
cd /root/binaries
wget https://github.com/etcd-io/etcd/releases/download/v3.5.18/etcd-v3.5.18-linux-amd64.tar.gz
tar -xzvf etcd-v3.5.18-linux-amd64.tar.gz
cd /root/binaries/etcd-v3.5.18-linux-amd64/
cp etcd etcdctl /usr/local/bin/

mkdir /root/certificates
cd /root/certificates

# create a Kubernetes certification authority certificate
openssl genrsa -out ca.key 2048
openssl req -new -key ca.key -subj "/CN=KUBERNETES-CA" -out ca.csr
openssl x509 -req -in ca.csr -signkey ca.key -out ca.crt -days 1000

# create etcd certificate
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

openssl genrsa -out etcd.key 2048
openssl req -new -key etcd.key -subj "/CN=etcd" -out etcd.csr -config etcd.cnf
openssl x509 -req -in etcd.csr -CA ca.crt -CAkey ca.key -CAcreateserial  -out etcd.crt -extensions v3_req -extfile etcd.cnf -days 2000

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

# create a kube-api server
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

# generate configuration file for CSR creation:
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

# uncomment to generate a Token auth file for static token file authentication.
# not recommended as per the CIS benchmark due to security concerns.
# TOKEN_PASSWORD=$(echo $RANDOM | md5sum | head -c 20) OR
# TOKEN_PASSWORD=$(head -c 20 /dev/urandom | base64) # with special characters included
# echo "$TOKEN_PASSWORD,dudung,01,admins" > /root/token.csv

# create an admin certificate for user "bob"
openssl genrsa -out bob.key 2048
openssl req -new -key bob.key -subj "/CN=bob/O=system:masters" -out bob.csr
openssl x509 -req -in bob.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out bob.crt -days 1000

# create a developer certificate for user "dudung"
openssl genrsa -out dudung.key 2048
openssl req -new -key dudung.key -subj "/CN=dudung/O=developers" -out dudung.csr
openssl x509 -req -in dudung.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out dudung.crt -days 2000

# create encryption config
cd /var/lib/etcd
ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)
cat > encryption-at-rest.yaml <<EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF

# Copy configuration to appropriate path:
mkdir /var/lib/kubernetes
mv encryption-at-rest.yaml /var/lib/kubernetes

# create audit policy file
cat > logging.yaml <<EOF
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
- level: Metadata
EOF

# integrate systemd with api server & start running
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
--client-ca-file=/root/certificates/ca.crt
--encryption-provider-config=/var/lib/kubernetes/encryption-at-rest.yaml
--audit-policy-file=/root/certificates/logging.yaml
--audit-log-path=/var/log/api-audit.log
--audit-log-maxage=30
--audit-log-maxbackup=10
--audit-log-maxsize=100 


[Install]
WantedBy=multi-user.target
EOF
# add this flag if you generated a static token auth file (not recommended)
# --token-auth-file=/root/token.csv

systemctl start kube-apiserver
