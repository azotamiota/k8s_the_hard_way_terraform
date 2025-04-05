resource "aws_default_vpc" "default" {
  tags = {
    Name = "Default VPC from terraform" # 172.31.0.0/16
  }
}

resource "aws_default_subnet" "default_az1" {
  availability_zone = "eu-west-2a"

  tags = {
    Name = "Default subnet for eu-west-2a from terraform" # 172.31.16.0/20
  }
}


data "aws_ami" "amzn-linux-2023-ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

resource "aws_instance" "sockets5" {
  ami                    = data.aws_ami.amzn-linux-2023-ami.id
  instance_type          = "t3.nano"
  subnet_id              = aws_default_subnet.default_az1.id
  key_name               = "socks5_proxy_key"
  vpc_security_group_ids = [aws_security_group.allow_ssh.id]

  cpu_options {
    core_count       = 1
    threads_per_core = 1
  }

  tags = {
    Name = "sockets5_proxy"
  }
}

resource "aws_key_pair" "socks5_key" {
  key_name   = "socks5_proxy_key"
  public_key = file("~/.ssh/socks5_proxy_key.pub")
}

output "instance_public_ip" {
  description = "The public IP address assigned to the instance, if applicable."
  value = try(
    # aws_eip.this[0].public_ip,
    aws_instance.sockets5.public_ip,
    # aws_instance.ignore_ami[0].public_ip,
    # aws_spot_instance_request.this[0].public_ip,
    null,
  )
}

resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh_socks5_proxy"
  description = "Allow SSH inbound traffic"
  vpc_id      = aws_default_vpc.default.id

  ingress {
    description = "SSH from your IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.home_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_ssh_socks5_proxy"
  }
}