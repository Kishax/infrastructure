# Lambda Module - EC2 Scheduler

# Archive Lambda function code
data "archive_file" "ec2_scheduler" {
  type        = "zip"
  source_file = "${path.module}/ec2-scheduler.py"
  output_path = "${path.module}/ec2-scheduler.zip"
}

# Lambda IAM Role
resource "aws_iam_role" "ec2_scheduler" {
  name = "kishax-${var.environment}-ec2-scheduler-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "kishax-${var.environment}-ec2-scheduler-lambda-role"
    Environment = var.environment
  }
}

# Lambda IAM Policy - EC2 Start/Stop
resource "aws_iam_role_policy" "ec2_scheduler_ec2" {
  name = "kishax-${var.environment}-ec2-scheduler-ec2-policy"
  role = aws_iam_role.ec2_scheduler.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:StartInstances",
          "ec2:StopInstances",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceStatus"
        ]
        Resource = "*"
      }
    ]
  })
}

# Lambda IAM Policy - CloudWatch Logs
resource "aws_iam_role_policy" "ec2_scheduler_logs" {
  name = "kishax-${var.environment}-ec2-scheduler-logs-policy"
  role = aws_iam_role.ec2_scheduler.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Lambda Function
resource "aws_lambda_function" "ec2_scheduler" {
  filename         = data.archive_file.ec2_scheduler.output_path
  function_name    = "kishax-${var.environment}-ec2-scheduler"
  role             = aws_iam_role.ec2_scheduler.arn
  handler          = "ec2-scheduler.lambda_handler"
  source_code_hash = data.archive_file.ec2_scheduler.output_base64sha256
  runtime          = "python3.12"
  timeout          = 60
  memory_size      = 128

  environment {
    variables = {
      ENVIRONMENT = var.environment
    }
  }

  tags = {
    Name        = "kishax-${var.environment}-ec2-scheduler"
    Environment = var.environment
  }
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "ec2_scheduler" {
  name              = "/aws/lambda/${aws_lambda_function.ec2_scheduler.function_name}"
  retention_in_days = 14

  tags = {
    Name        = "kishax-${var.environment}-ec2-scheduler-logs"
    Environment = var.environment
  }
}

# Lambda Permission - Allow EventBridge Scheduler to invoke
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ec2_scheduler.function_name
  principal     = "scheduler.amazonaws.com"
}
