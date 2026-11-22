
# Find the existing default VPC
data "aws_vpc" "default" {
  default = true
}

# Find subnets belonging to the default VPC
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Select the first available default subnet
data "aws_subnet" "selected" {
  id = data.aws_subnets.default.ids[0]
}

# Find the latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

# Initial security group
resource "aws_security_group" "ec2_normal" {
  name        = "${var.project_name}-normal-sg"
  description = "Initial security group for EC2 test instance"
  vpc_id      = data.aws_vpc.default.id

  # No inbound rules

  # Allow outbound traffic initially
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-normal-sg"
  }
}

# Quarantine security group
resource "aws_security_group" "ec2_quarantine" {
  name        = "${var.project_name}-quarantine-sg"
  description = "Isolates suspected compromised EC2 instances"
  vpc_id      = data.aws_vpc.default.id

  # No ingress rules
  # No egress rules

  tags = {
    Name = "${var.project_name}-quarantine-sg"
  }
}

# EC2 test instance
resource "aws_instance" "test_instance" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type

  subnet_id = data.aws_subnet.selected.id

  vpc_security_group_ids = [
    aws_security_group.ec2_normal.id
  ]

  associate_public_ip_address = false

  monitoring = false

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name = "${var.project_name}-test-instance"
    Role = "IncidentResponseTest"
  }
}
