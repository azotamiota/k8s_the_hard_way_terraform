#!/bin/bash

# setup containerd
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sysctl --system

sudo apt-get update
apt-get install -y containerd
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml

sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
cat /etc/containerd/config.toml | grep SystemdCgroup

systemctl restart containerd

# kernel parameter configuration
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

sudo sysctl --system

# configuring repo and installation
sudo apt-get update
apt-get install -y apt-transport-https ca-certificates curl gpg

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
apt-get install -y kubelet=1.32.0-1.1 kubeadm=1.32.0-1.1 kubectl=1.32.0-1.1 cri-tools=1.32.0-1.1
sudo apt-mark hold kubelet kubeadm kubectl
systemctl enable --now kubelet

# initialize cluster with kubeadm:
kubeadm init --pod-network-cidr=192.168.0.0/16 --kubernetes-version=1.32.0
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# remove the taint:
kubectl taint nodes --all node-role.kubernetes.io/control-plane-

# install network addon (Calico):
# kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.1/manifests/tigera-operator.yaml
# kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.1/manifests/custom-resources.yaml
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/refs/heads/master/manifests/calico.yaml
