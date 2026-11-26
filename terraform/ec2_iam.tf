# IAM Instance role for cloudwatch-agent
resource "aws_iam_role" "ec2_cloudwatch_role" {
  name = "${var.project_name}-ec2-cloudwatch-role"

  # Allow EC2 Instance to Assume this Role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRole"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

# Permission Policy attached to the ec2 cloudwatch role
resource "aws_iam_role_policy" "ec2_cloudwatch_policy" {
  name = "${var.project_name}-ec2-cloudwatch-logs"
  role =  aws_iam_role.ec2_cloudwatch_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogStreams"
      ]
      Reource = "arn:aws:logs:ap-south-1:*:log-group:/ec2/incident-response-lab/secure:log-stream:*"
    }]
  })
}

# Attach the EC2 Cloudwatch role to the instance profile
resource "aws_iam_instance_profile" "ec2_cloudwatch_profile" {
  name = "${var.project_name}-ec2-cloudwatch-profile"
  role = aws_iam_role.ec2_cloudwatch_role.name
}
