# Kishax Infrastructure - Outputs

# VPC Outputs
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

# EC2 Outputs
output "mc_server_instance_id" {
  description = "Minecraft Server (i-a) Instance ID"
  value       = module.ec2.mc_server_instance_id
}

output "mc_server_elastic_ip" {
  description = "Minecraft Server Elastic IP"
  value       = module.ec2.mc_server_elastic_ip
}

output "api_server_instance_id" {
  description = "API Server (i-b) Instance ID"
  value       = module.ec2.api_server_instance_id
}

output "api_server_private_ip" {
  description = "API Server Private IP"
  value       = module.ec2.api_server_private_ip
}

output "web_server_instance_id" {
  description = "Web Server (i-c) Instance ID"
  value       = module.ec2.web_server_instance_id
}

output "web_server_public_ip" {
  description = "Web Server Public IP"
  value       = module.ec2.web_server_public_ip
}

output "jump_server_instance_id" {
  description = "Jump Server (i-d) Instance ID"
  value       = module.ec2.jump_server_instance_id
}

# RDS Outputs
output "postgres_endpoint" {
  description = "PostgreSQL RDS endpoint"
  value       = module.rds.postgres_endpoint
  sensitive   = true
}

output "mysql_endpoint" {
  description = "MySQL RDS endpoint"
  value       = module.rds.mysql_endpoint
  sensitive   = true
}

# SQS Outputs
output "to_mc_queue_url" {
  description = "TO MC Queue URL"
  value       = module.sqs.to_mc_queue_url
}

output "to_web_queue_url" {
  description = "TO WEB Queue URL"
  value       = module.sqs.to_web_queue_url
}

output "discord_queue_url" {
  description = "Discord Queue URL"
  value       = module.sqs.discord_queue_url
}

# CloudFront Outputs
output "cloudfront_distribution_id" {
  description = "CloudFront Distribution ID"
  value       = module.cloudfront.cloudfront_distribution_id
}

output "cloudfront_domain_name" {
  description = "CloudFront Distribution Domain Name"
  value       = module.cloudfront.cloudfront_domain_name
}

# Route53 Outputs
output "mc_domain_record" {
  description = "Minecraft Server Domain Record"
  value       = "${var.mc_domain_name} -> ${module.ec2.mc_server_elastic_ip}"
}

output "web_domain_record" {
  description = "Web Application Domain Record"
  value       = "${var.web_domain_name} -> ${module.cloudfront.cloudfront_domain_name}"
}
