
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

  # **ALLOW SSH FROM OUR KALI VM ONLY**
  ingress {
    description = "Temporary SSH from Kali VM"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.attacker_cidr]
  }

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

resource "aws_key_pair" "kali" {
  key_name   = "${var.project_name}-kali-key"
  public_key = file("${path.module}/kali-ec2.pub")

  tags = {
    Name = "${var.project_name}-kali-key"
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
  # Assign Public IP so we can attack EC2 Instance from our Kali VM and generate some telemetry
  associate_public_ip_address = true
  key_name                    = aws_key_pair.kali.key_name
  # Attach the IAM Instance Profile to the EC2 Instance
  iam_instance_profile = aws_iam_instance_profile.ec2_cloudwatch_profile.name

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
