# Kubernetes the Hard Way  
**Building a Kubernetes cluster from scratch on AWS EC2 using Infrastructure-as-Code (Terraform)**
*Please Note: This project is still in progress* 

## Project Overview  
This project demonstrates hands-on Kubernetes architecture knowledge by manually configuring core components (etcd, kube-apiserver, certificates) on an EC2 instance via Terraform and systemd.  

## Key Steps  
- Provisioned an EC2 instance using Terraform with custom user data.  
- Manually configured in user data:  
  - etcd server with TLS certificates  
  - systemd unit files for etcd and kube-apiserver  
  - Kubernetes API server with service account certificates
  - Static token file authentication
- Automated initial setup while preserving the "hard way" learning approach.  

## Technologies Used  
Terraform, AWS EC2, Kubernetes, systemd, TLS certificate management  
