# Dynamic AMI
# data "aws_ami" "amzn-linux-2023-ami" {
#   most_recent = true
#   owners      = ["amazon"]

#   filter {
#     name   = "name"
#     values = ["al2023-ami-2023.*-x86_64"]
#   }
# }

# Static AMI used for ETCD & kube-apiserver practice
resource "aws_instance" "kubeadm_worker" {
  # ami                    = data.aws_ami.amzn-linux-2023-ami.id
  ami                    = "ami-084568db4383264d4"
  instance_type          = "t3.nano"
  subnet_id              = aws_default_subnet.default_az1.id
  key_name               = "kubeadm_worker_key"
  vpc_security_group_ids = [aws_security_group.allow_all_traffic.id]
  user_data              = file("./scripts/worker_node_userdata.sh")

  tags = {
    Name = "kubeadm-worker"
  }
}

resource "aws_key_pair" "kubeadm_worker_key" {
  key_name   = "kubeadm_worker_key"
  public_key = file("~/.ssh/cks_ec2_key.pub") # MacBook private key
  # public_key = file("~/.ssh/socks5_proxy_key.pub") # Dell private key
}

output "kubeadm_worker_public_ip" {
  description = "The public IP address assigned to the kubeadm worker node"
  value = try(
    # aws_eip.this[0].public_ip,
    aws_instance.kubeadm_worker.public_ip,
    # aws_instance.ignore_ami[0].public_ip,
    # aws_spot_instance_request.this[0].public_ip,
    null,
  )
}
