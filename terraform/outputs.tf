
output "ec2_instance_id" {
  description = "ID of the EC2 test instance"
  value       = aws_instance.test_instance.id
}

output "ec2_private_ip" {
  description = "Private IP address of the test instance"
  value       = aws_instance.test_instance.private_ip
}

output "normal_security_group_id" {
  description = "Initial EC2 security group"
  value       = aws_security_group.ec2_normal.id
}

output "quarantine_security_group_id" {
  description = "Security group used for EC2 isolation"
  value       = aws_security_group.ec2_quarantine.id
}

output "ec2_ami_id" {
  description = "Amazon Linux 2023 AMI ID"
  value       = data.aws_ami.amazon_linux.id
}
