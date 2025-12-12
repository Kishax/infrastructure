# SQS Module - Main Configuration

# Discord Queue
resource "aws_sqs_queue" "discord" {
  name                      = "kishax-${var.environment}-discord-queue"
  visibility_timeout_seconds = 300
  message_retention_seconds = 1209600  # 14 days
  receive_wait_time_seconds = 20

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.discord_dlq.arn
    maxReceiveCount     = 3
  })

  tags = {
    Name      = "kishax-${var.environment}-discord-queue"
    Component = "DiscordBot"
  }
}

# Discord Dead Letter Queue
resource "aws_sqs_queue" "discord_dlq" {
  name                      = "kishax-${var.environment}-discord-dlq"
  message_retention_seconds = 1209600  # 14 days

  tags = {
    Name      = "kishax-${var.environment}-discord-dlq"
    Component = "DiscordBot"
  }
}

# TO MC Queue (WEB → MC)
resource "aws_sqs_queue" "to_mc" {
  name                      = "kishax-${var.environment}-to-mc-queue"
  visibility_timeout_seconds = 300
  message_retention_seconds = 1209600  # 14 days
  receive_wait_time_seconds = 20

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.to_mc_dlq.arn
    maxReceiveCount     = 3
  })

  tags = {
    Name      = "kishax-${var.environment}-to-mc-queue"
    Component = "ToMcCommunication"
  }
}

# TO MC Dead Letter Queue
resource "aws_sqs_queue" "to_mc_dlq" {
  name                      = "kishax-${var.environment}-to-mc-dlq"
  message_retention_seconds = 1209600  # 14 days

  tags = {
    Name      = "kishax-${var.environment}-to-mc-dlq"
    Component = "ToMcCommunication"
  }
}

# TO WEB Queue (MC → WEB)
resource "aws_sqs_queue" "to_web" {
  name                      = "kishax-${var.environment}-to-web-queue"
  visibility_timeout_seconds = 300
  message_retention_seconds = 1209600  # 14 days
  receive_wait_time_seconds = 20

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.to_web_dlq.arn
    maxReceiveCount     = 3
  })

  tags = {
    Name      = "kishax-${var.environment}-to-web-queue"
    Component = "ToWebCommunication"
  }
}

# TO WEB Dead Letter Queue
resource "aws_sqs_queue" "to_web_dlq" {
  name                      = "kishax-${var.environment}-to-web-dlq"
  message_retention_seconds = 1209600  # 14 days

  tags = {
    Name      = "kishax-${var.environment}-to-web-dlq"
    Component = "ToWebCommunication"
  }
}

# SQS Access IAM User (MC-Web Communication)
resource "aws_iam_user" "mc_web_sqs" {
  name = "kishax-${var.environment}-mc-web-sqs-user"

  tags = {
    Name      = "kishax-${var.environment}-mc-web-sqs-user"
    Component = "McWebCommunication"
  }
}

# SQS Access Policy for IAM User
resource "aws_iam_user_policy" "mc_web_sqs" {
  name = "kishax-${var.environment}-mc-web-sqs-policy"
  user = aws_iam_user.mc_web_sqs.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = [
          aws_sqs_queue.to_mc.arn,
          aws_sqs_queue.to_web.arn,
          aws_sqs_queue.discord.arn
        ]
      }
    ]
  })
}

# Access Key for SQS User
resource "aws_iam_access_key" "mc_web_sqs" {
  user = aws_iam_user.mc_web_sqs.name
}

# SSM Parameters for SQS User Credentials
resource "aws_ssm_parameter" "mc_web_sqs_access_key" {
  name        = "/kishax/mc-web-sqs/access-key-id"
  description = "MC-Web SQS User Access Key ID"
  type        = "String"
  value       = aws_iam_access_key.mc_web_sqs.id

  tags = {
    Component = "McWebCommunication"
  }
}

resource "aws_ssm_parameter" "mc_web_sqs_secret_key" {
  name        = "/kishax/mc-web-sqs/secret-access-key"
  description = "MC-Web SQS User Secret Access Key"
  type        = "SecureString"
  value       = aws_iam_access_key.mc_web_sqs.secret

  tags = {
    Component = "McWebCommunication"
  }
}

# SSM Parameters for Queue URLs
resource "aws_ssm_parameter" "to_mc_queue_url" {
  name        = "/kishax/sqs/to-mc-queue-url"
  description = "TO MC Queue URL"
  type        = "String"
  value       = aws_sqs_queue.to_mc.url

  tags = {
    Component = "ToMcCommunication"
  }
}

resource "aws_ssm_parameter" "to_web_queue_url" {
  name        = "/kishax/sqs/to-web-queue-url"
  description = "TO WEB Queue URL"
  type        = "String"
  value       = aws_sqs_queue.to_web.url

  tags = {
    Component = "ToWebCommunication"
  }
}

resource "aws_ssm_parameter" "discord_queue_url" {
  name        = "/kishax/sqs/to-discord-queue-url"
  description = "Discord Queue URL"
  type        = "String"
  value       = aws_sqs_queue.discord.url

  tags = {
    Component = "DiscordBot"
  }
}
