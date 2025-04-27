resource "aws_default_vpc" "default" {
  tags = {
    Name = "Default VPC from terraform"
  }
}

resource "aws_default_subnet" "default_az1" {
  availability_zone = "us-east-1a"

  tags = {
    Name = "Default subnet for us-east-1a from terraform"
  }
}

# Dynamic AMI
# data "aws_ami" "amzn-linux-2023-ami" {
#   most_recent = true
#   owners      = ["amazon"]

#   filter {
#     name   = "name"
#     values = ["al2023-ami-2023.*-x86_64"]
#   }
# }

# Static AMI used for ETCD server practice
resource "aws_instance" "cks_ec2" {
  # ami                    = data.aws_ami.amzn-linux-2023-ami.id
  ami                    = "ami-084568db4383264d4"
  instance_type          = "t3.nano"
  subnet_id              = aws_default_subnet.default_az1.id
  key_name               = "cks_ec2_key"
  vpc_security_group_ids = [aws_security_group.allow_all_traffic.id]
  user_data              = file("./scripts/userdata.sh")

  cpu_options {
    core_count       = 1
    threads_per_core = 1
  }

  tags = {
    Name = "cks_ec2"
  }
}

resource "aws_key_pair" "cks_ec2_key" {
  key_name   = "cks_ec2_key"
  public_key = file("~/.ssh/cks_ec2_key.pub")
}

output "instance_public_ip" {
  description = "The public IP address assigned to the instance, if applicable."
  value = try(
    # aws_eip.this[0].public_ip,
    aws_instance.cks_ec2.public_ip,
    # aws_instance.ignore_ami[0].public_ip,
    # aws_spot_instance_request.this[0].public_ip,
    null,
  )
}

resource "aws_security_group" "allow_all_traffic" {
  name        = "ip_restricted_allow_all_traffic_cks_ec2"
  description = "Allow inbound traffic only from my IP"
  vpc_id      = aws_default_vpc.default.id

  ingress {
    description = "All traffic from my home IP only"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.home_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ip_restricted_allow_all_traffic_cks_ec2"
  }
}