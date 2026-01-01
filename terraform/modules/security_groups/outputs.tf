# Security Groups Module - Outputs

output "mc_server_sg_id" {
  description = "MC Server Security Group ID"
  value       = aws_security_group.mc_server.id
}

output "api_server_sg_id" {
  description = "API Server Security Group ID"
  value       = aws_security_group.api_server.id
}

output "web_server_sg_id" {
  description = "Web Server Security Group ID"
  value       = aws_security_group.web_server.id
}

output "jump_server_sg_id" {
  description = "Jump Server Security Group ID"
  value       = aws_security_group.jump_server.id
}

output "rds_security_group_id" {
  description = "RDS Security Group ID"
  value       = aws_security_group.rds.id
}

output "terraria_server_sg_id" {
  description = "Terraria Server Security Group ID"
  value       = aws_security_group.terraria_server.id
}
