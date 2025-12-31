# SQS Module - Outputs

output "discord_queue_url" {
  description = "Discord Queue URL"
  value       = aws_sqs_queue.discord.url
}

output "discord_queue_arn" {
  description = "Discord Queue ARN"
  value       = aws_sqs_queue.discord.arn
}

output "to_mc_queue_url" {
  description = "TO MC Queue URL"
  value       = aws_sqs_queue.to_mc.url
}

output "to_mc_queue_arn" {
  description = "TO MC Queue ARN"
  value       = aws_sqs_queue.to_mc.arn
}

output "to_web_queue_url" {
  description = "TO WEB Queue URL"
  value       = aws_sqs_queue.to_web.url
}

output "to_web_queue_arn" {
  description = "TO WEB Queue ARN"
  value       = aws_sqs_queue.to_web.arn
}
