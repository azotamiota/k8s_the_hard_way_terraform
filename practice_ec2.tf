# # Dynamic AMI
# # data "aws_ami" "amzn-linux-2023-ami" {
# #   most_recent = true
# #   owners      = ["amazon"]

# #   filter {
# #     name   = "name"
# #     values = ["al2023-ami-2023.*-x86_64"]
# #   }
# # }

# # Static AMI used for ETCD & kube-apiserver practice
# resource "aws_instance" "cks_ec2" {
#   # ami                    = data.aws_ami.amzn-linux-2023-ami.id
#   ami                    = "ami-084568db4383264d4"
#   instance_type          = "t4g.nano"
#   subnet_id              = aws_default_subnet.default_az1.id
#   key_name               = "cks_ec2_key"
#   vpc_security_group_ids = [aws_security_group.allow_all_traffic.id]
#   user_data              = file("./scripts/userdata.sh")

#   cpu_options {
#     core_count       = 1
#     threads_per_core = 1
#   }

#   tags = {
#     Name = "cks_ec2"
#   }
# }

# resource "aws_key_pair" "cks_ec2_key" {
#   key_name   = "cks_ec2_key"
#   public_key = file("~/.ssh/cks_ec2_key.pub") # MacBook private key
#   # public_key = file("~/.ssh/socks5_proxy_key.pub") # Dell private key
# }

# output "instance_public_ip" {
#   description = "The public IP address assigned to the instance, if applicable."
#   value = try(
#     # aws_eip.this[0].public_ip,
#     aws_instance.cks_ec2.public_ip,
#     # aws_instance.ignore_ami[0].public_ip,
#     # aws_spot_instance_request.this[0].public_ip,
#     null,
#   )
# }
