# Lambda Module - Outputs

output "ec2_scheduler_function_name" {
  description = "EC2 Scheduler Lambda function name"
  value       = aws_lambda_function.ec2_scheduler.function_name
}

output "ec2_scheduler_function_arn" {
  description = "EC2 Scheduler Lambda function ARN"
  value       = aws_lambda_function.ec2_scheduler.arn
}

output "ec2_scheduler_role_arn" {
  description = "EC2 Scheduler Lambda IAM role ARN"
  value       = aws_iam_role.ec2_scheduler.arn
}
