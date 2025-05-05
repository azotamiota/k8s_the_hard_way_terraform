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

resource "aws_security_group" "allow_all_traffic" {
  name        = "ip_restricted_allow_all_traffic_cks_ec2"
  description = "Allow inbound traffic only from my IP"
  vpc_id      = aws_default_vpc.default.id

  ingress {
    description = "All traffic from my home IP only"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.home_ip, aws_default_subnet.default_az1.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ip_restricted_allow_all_traffic"
  }
}
