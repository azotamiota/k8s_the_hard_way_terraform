# Kubernetes the Hard Way

Creating a Kubernetes cluster on an AWS EC2 virtual machine from scratch by using IaC approach.

## Steps done

- Created a basic EC2 instance configuration by Terraform.
- Added user data to
  - create an etcd server & certificates
  - create systemd file for etcd
  - create a kube-apiserver & certificates
  - generate service account certificates
  - integrate systemd with kube-apiserver
