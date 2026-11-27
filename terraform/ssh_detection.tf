# Lambda execution role
resource "aws_iam_role" "lambda_execution_role" {
  name = "${var.project_name}-lambda-role"
  assume_role_policy = jasonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRole"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# Lambda Execution role permission policy
resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.project_name}-lambda-policy"
  role = aws_iam_role.lambda_execution_role.arn

  policy = jasonencode({
    Version = "2012-10-17"
    Statement = [
      # Permission to read ssh events from cloudwatch log group, where cloudwatch-agent stores the logs
      {
      Sid    = "CloudWatchLogsRead"
      Effect = "Allow"
      Action = [
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams",
        "logs:GetLogEvents",
        "logs:FilterLogEvents"
      ]
      Resource = "arn:aws:logs:ap-south-1:*:log-group:/ec2/incident-response-lab/secure:*"
    },
    # Permission to record lambda runtime events
    {
      Sid = "CloudWatchLogsLambdaWrite"
      Effect = "Allow"
      Action = [
        "logs:PutLogEvents",
        "logs:CreateLogStreams"
      ]
      Resource = aws_cloudwatch_log_group.ssh_detection_lambda_logs.arn
    },
    # Permission to Write to SSH Auth Events table
    {
      Sid = "DynamoDBSSHAuthEventsWrite"
      Effect = "Allow"
      Action = [
        "dynamodb:PutItems",
        "dynamodb:Query"
      ]
      Resource = aws_dynamodb_table.ssh_auth_events.arn

    },
    # Permission to Write to EC2 Security Incidents table
    {
      Sid = "DynamoDBEC2SecurityIncidentWrite"
      Effect = "Allow"
      Action = [
        "dynamodb:PutItems",
      ]
      Resource = aws_dynamodb_table.ec2_security_incidents.arn
    },
    # Permission to Publish Notification
    {
      Sid = "SNSPublishIncidents"
      Effect = "Allow",
      Action = "sns:Publish"
      Resource = aws_sns_topic.security_alerts.arn
    }
    ]
  })
}

# cloudwatch log group for lambda detection runtime environment
resource "aws_cloudwatch_log_group" "ssh_detection_lambda_logs" {
  name = "aws/lambda/ssh-authentication-detection"
  retention_in_days = 7
}
# Lambda Function to detect SSH Authentication Logs
resource "aws_lambda_function" "ssh_detector_lambda" {
  function_name = "${var.project_name}-lambda-function"
  role = aws_iam_role.lambda_execution_role

  filename = "${path.module}/scripts/detection.zip"
  source_code_hash = filebase64sha256("${path.module}/scripts/detection.zip")

  handler = "detection.lambda_handler"

  package_type = "zip"
  timeout = 30
  runtime = "python3.12"
  memory_size = "128"

  environment {
    variables = {
      FAILURE_EVENTS_TABLE = aws_dynamodb_table.ssh_auth_events.restore_source_name
      INCIDENTS_TABLE = aws_dynamodb_table.ec2_security_incidents.name
      SNS_TOPIC_ARN = aws_sns_topic.security_alerts.arn
      FAILURE_THRESHOLD = "5"
      WINDOW_SECONDS = "300"
    }
  }
  depends_on = [
    aws_iam_role.ec2_cloudwatch_role,
    aws_cloudwatch_log_group.ssh_detection_lambda_logs
  ]
}
# Allow Cloudwatch Logs to Invoke Lambda
resource "aws_lambda_permission" "allow_cloudwatch_logs" {
  statement_id = "AllowExecutionFromCloudWatchLogs"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ssh_detector_lambda.name
  principal = "lambda.amazonaws.com"
  source_arn = "${aws_cloudwatch_log_group.ec2_secure_logs.arn}:*"
}
/*
 Cloudwatch log subscription filter
 filters SSH Authentication events from cloudwatch log group
 and sends them to lambda function for evaluation
*/
resource "aws_cloudwatch_log_subscription_filter" "log_filter" {
  name = "${var.project_name}-cloudwatch-subscription-filter"
  log_group_name = aws_cloudwatch_log_group.ec2_secure_logs.name
  destination_arn = aws_lambda_function.ssh_detector_lambda.arn

  filter_pattern = "?Failed ?Invalid ?authentication"

  depends_on = [
    aws_lambda_permission.allow_cloudwatch_logs
  ]

}

# DynamoDB Table for Recording SSH Failed Authentication
resource "aws_dynamodb_table" "ssh_auth_events" {
  name = "${var.project_name}-ssh-auth"

}
# DynamoDB Table for Recording EC2 Security Incidents
resource "aws_dynamodb_table" "ec2_security_incidents" {
  name = "${var.project_name}-ec2-security-incidents"
}


# SNS Topic
resource "aws_sns_topic" "security_alerts" {
  name = "${var.project_name}-security-alerts"

  tags = {
    Name = "EC2 Security Alerts"
  }
}
