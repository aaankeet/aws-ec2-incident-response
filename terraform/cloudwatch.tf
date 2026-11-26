# Cloudwatch log group for SSH Authentication Logs from EC2 Instance
resource "aws_cloudwatch_log_group" "ec2_secure_logs" {
  name              = "/ec2/incident-response-lab/secure"
  retention_in_days = 7

  tags = {
    Name = "EC2 SSH Security Logs"
  }
}
