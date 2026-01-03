# EventBridge Module - EC2 Scheduler

# EventBridge Scheduler IAM Role
resource "aws_iam_role" "scheduler" {
  name = "kishax-${var.environment}-scheduler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "scheduler.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "kishax-${var.environment}-scheduler-role"
    Environment = var.environment
  }
}

# EventBridge Scheduler IAM Policy - Lambda Invoke
resource "aws_iam_role_policy" "scheduler_lambda" {
  name = "kishax-${var.environment}-scheduler-lambda-policy"
  role = aws_iam_role.scheduler.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = var.lambda_function_arn
      }
    ]
  })
}

# ============================================================================
# Start Schedule (22:00 JST)
# ============================================================================

# EventBridge Scheduler - Start Instances at 22:00 JST
resource "aws_scheduler_schedule" "start_instances" {
  name        = "kishax-${var.environment}-start-instances"
  description = "Start MC, API, and Web servers at 22:00 JST"

  # Flexible time window
  flexible_time_window {
    mode = "OFF"
  }

  # Cron expression: 22:00 JST = 13:00 UTC (JST = UTC+9)
  schedule_expression          = "cron(0 13 * * ? *)"
  schedule_expression_timezone = "Asia/Tokyo"

  target {
    arn      = var.lambda_function_arn
    role_arn = aws_iam_role.scheduler.arn

    input = jsonencode({
      action = "start"
      instance_ids = [
        var.mc_server_instance_id,
        var.api_server_instance_id,
        var.web_server_instance_id
      ]
    })
  }
}

# ============================================================================
# Stop Schedule (27:00 JST = next day 03:00 JST)
# ============================================================================

# EventBridge Scheduler - Stop Instances at 03:00 JST (27:00 JST)
resource "aws_scheduler_schedule" "stop_instances" {
  name        = "kishax-${var.environment}-stop-instances"
  description = "Stop MC, API, and Web servers at 03:00 JST (27:00)"

  # Flexible time window
  flexible_time_window {
    mode = "OFF"
  }

  # Cron expression: 03:00 JST = 18:00 UTC (previous day)
  schedule_expression          = "cron(0 18 * * ? *)"
  schedule_expression_timezone = "Asia/Tokyo"

  target {
    arn      = var.lambda_function_arn
    role_arn = aws_iam_role.scheduler.arn

    input = jsonencode({
      action = "stop"
      instance_ids = [
        var.mc_server_instance_id,
        var.api_server_instance_id,
        var.web_server_instance_id
      ]
    })
  }
}
