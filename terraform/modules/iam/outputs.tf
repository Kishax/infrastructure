# IAM Module - Outputs

output "mc_server_role_name" {
  description = "MC Server IAM Role Name"
  value       = aws_iam_role.mc_server.name
}

output "mc_server_instance_profile_name" {
  description = "MC Server Instance Profile Name"
  value       = aws_iam_instance_profile.mc_server.name
}

output "api_server_role_name" {
  description = "API Server IAM Role Name"
  value       = aws_iam_role.api_server.name
}

output "api_server_instance_profile_name" {
  description = "API Server Instance Profile Name"
  value       = aws_iam_instance_profile.api_server.name
}

output "web_server_role_name" {
  description = "Web Server IAM Role Name"
  value       = aws_iam_role.web_server.name
}

output "web_server_instance_profile_name" {
  description = "Web Server Instance Profile Name"
  value       = aws_iam_instance_profile.web_server.name
}

output "jump_server_role_name" {
  description = "Jump Server IAM Role Name"
  value       = aws_iam_role.jump_server.name
}

output "jump_server_instance_profile_name" {
  description = "Jump Server Instance Profile Name"
  value       = aws_iam_instance_profile.jump_server.name
}

# SQS Access User Outputs
output "sqs_access_user_name" {
  description = "SQS Access IAM User Name"
  value       = aws_iam_user.sqs_access.name
}

output "sqs_access_key_id" {
  description = "SQS Access Key ID (stored in SSM)"
  value       = aws_iam_access_key.sqs_access.id
  sensitive   = true
}

output "sqs_secret_access_key" {
  description = "SQS Secret Access Key (stored in SSM)"
  value       = aws_iam_access_key.sqs_access.secret
  sensitive   = true
}

output "sqs_access_key_ssm_parameter" {
  description = "SSM Parameter name for SQS Access Key ID"
  value       = aws_ssm_parameter.sqs_access_key_id.name
}

output "sqs_secret_access_key_ssm_parameter" {
  description = "SSM Parameter name for SQS Secret Access Key"
  value       = aws_ssm_parameter.sqs_secret_access_key.name
}
