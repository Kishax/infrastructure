# EC2 Module - Outputs

output "mc_server_instance_id" {
  description = "MC Server Instance ID"
  value       = aws_instance.mc_server.id
}

output "mc_server_elastic_ip" {
  description = "MC Server Elastic IP"
  value       = aws_eip.mc_server.public_ip
}

output "mc_server_private_ip" {
  description = "MC Server Private IP"
  value       = aws_instance.mc_server.private_ip
}

output "api_server_instance_id" {
  description = "API Server Instance ID"
  value       = aws_instance.api_server.id
}

output "api_server_private_ip" {
  description = "API Server Private IP"
  value       = aws_instance.api_server.private_ip
}

output "web_server_instance_id" {
  description = "Web Server Instance ID"
  value       = aws_instance.web_server.id
}

output "web_server_public_ip" {
  description = "Web Server Public IP"
  value       = aws_instance.web_server.public_ip
}

output "web_server_public_dns" {
  description = "Web Server Public DNS"
  value       = aws_instance.web_server.public_dns
}

output "web_server_private_ip" {
  description = "Web Server Private IP"
  value       = aws_instance.web_server.private_ip
}

output "jump_server_instance_id" {
  description = "Jump Server Instance ID"
  value       = aws_instance.jump_server.id
}

output "jump_server_private_ip" {
  description = "Jump Server Private IP"
  value       = aws_instance.jump_server.private_ip
}

output "terraria_server_instance_id" {
  description = "Terraria Server Instance ID"
  value       = aws_instance.terraria_server.id
}

output "terraria_server_elastic_ip" {
  description = "Terraria Server Elastic IP"
  value       = aws_eip.terraria_server.public_ip
}

output "terraria_server_private_ip" {
  description = "Terraria Server Private IP"
  value       = aws_instance.terraria_server.private_ip
}
