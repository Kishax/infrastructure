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
