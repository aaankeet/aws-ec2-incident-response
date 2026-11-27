# Lambda execution role
resource "aws_iam_role" "lambda_execution_role" {
  name = "${var.project_name}-lambda-role"
  assume_role_policy = jsonencode({
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
  role = aws_iam_role.lambda_execution_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogsLambdaWrite"
        Effect = "Allow"
        Action = [
          "logs:PutLogEvents",
          "logs:CreateLogStream"
        ]
        Resource = "${aws_cloudwatch_log_group.ssh_detection_lambda_logs.arn}:*"
      },
      # Permission to Write to SSH Auth Events table
      {
        Sid    = "DynamoDBSSHAuthEventsWrite"
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:Query"
        ]
        Resource = aws_dynamodb_table.ssh_auth_events.arn

      },
      # Permission to Write to EC2 Security Incidents table
      {
        Sid    = "DynamoDBEC2SecurityIncidentWrite"
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
        ]
        Resource = aws_dynamodb_table.ec2_security_incidents.arn
      },
      # Permission to Publish Notification
      {
        Sid      = "SNSPublishIncidents"
        Effect   = "Allow",
        Action   = "sns:Publish"
        Resource = aws_sns_topic.security_alerts.arn
      }
    ]
  })
}

# cloudwatch log group for lambda detection runtime environment
resource "aws_cloudwatch_log_group" "ssh_detection_lambda_logs" {
  name              = "/aws/lambda/${var.project_name}-ssh-authentication-detection"
  retention_in_days = 7
}
# Lambda Function to detect SSH Authentication Logs
resource "aws_lambda_function" "ssh_detector_lambda" {
  function_name = "${var.project_name}-ssh-authentication-detection"
  role          = aws_iam_role.lambda_execution_role.arn

  filename         = "${path.module}/scripts/detection.zip"
  source_code_hash = filebase64sha256("${path.module}/scripts/detection.zip")

  handler = "detection.lambda_handler"
  runtime = "python3.12"

  timeout     = 30
  memory_size = 128

  environment {
    variables = {
      FAILURE_EVENTS_TABLE = aws_dynamodb_table.ssh_auth_events.name
      INCIDENTS_TABLE      = aws_dynamodb_table.ec2_security_incidents.name
      SNS_TOPIC_ARN        = aws_sns_topic.security_alerts.arn
      FAILURE_THRESHOLD    = "5"
      WINDOW_SECONDS       = "300"
    }
  }
  depends_on = [
    aws_iam_role_policy.lambda_policy,
    aws_cloudwatch_log_group.ssh_detection_lambda_logs
  ]
}
# Allow Cloudwatch Logs to Invoke Lambda
resource "aws_lambda_permission" "allow_cloudwatch_logs" {
  statement_id  = "AllowExecutionFromCloudWatchLogs"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ssh_detector_lambda.function_name
  principal     = "logs.amazonaws.com"

  source_arn = "${aws_cloudwatch_log_group.ec2_secure_logs.arn}:*"
}

/*
 Cloudwatch log subscription filter
 filters SSH Authentication events from cloudwatch log group
 and sends them to lambda function for evaluation
*/
resource "aws_cloudwatch_log_subscription_filter" "log_filter" {
  name            = "${var.project_name}-cloudwatch-subscription-filter"
  log_group_name  = aws_cloudwatch_log_group.ec2_secure_logs.name
  destination_arn = aws_lambda_function.ssh_detector_lambda.arn

  filter_pattern = "?Failed ?Invalid ?authentication"

  depends_on = [
    aws_lambda_permission.allow_cloudwatch_logs
  ]

}

# DynamoDB Table for Recording SSH Failed Authentication
resource "aws_dynamodb_table" "ssh_auth_events" {
  name         = "${var.project_name}-ssh-auth-events"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "source_ip"
  range_key    = "event_key"

  attribute {
    name = "source_ip"
    type = "S"
  }
  attribute {
    name = "event_key"
    type = "S"
  }
  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }
}
# DynamoDB Table for Recording EC2 Security Incidents
resource "aws_dynamodb_table" "ec2_security_incidents" {
  name         = "${var.project_name}-ec2-security-incidents"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "incident_id"

  attribute {
    name = "incident_id"
    type = "S"
  }
  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }
}


# SNS Topic
resource "aws_sns_topic" "security_alerts" {
  name = "${var.project_name}-security-alerts"

  tags = {
    Name = "EC2 Security Alerts"
  }
}
