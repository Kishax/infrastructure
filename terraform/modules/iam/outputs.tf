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
