# EventBridge Module - Outputs

output "start_schedule_arn" {
  description = "EventBridge start schedule ARN"
  value       = aws_scheduler_schedule.start_instances.arn
}

output "stop_schedule_arn" {
  description = "EventBridge stop schedule ARN"
  value       = aws_scheduler_schedule.stop_instances.arn
}

output "scheduler_role_arn" {
  description = "EventBridge scheduler IAM role ARN"
  value       = aws_iam_role.scheduler.arn
}
