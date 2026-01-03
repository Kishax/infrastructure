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

output "terraria_server_instance_id" {
  description = "Terraria Server (i-e) Instance ID"
  value       = module.ec2.terraria_server_instance_id
}

output "terraria_server_elastic_ip" {
  description = "Terraria Server Elastic IP"
  value       = module.ec2.terraria_server_elastic_ip
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

output "terraria_domain_record" {
  description = "Terraria Server Domain Record"
  value       = "${var.terraria_domain_name} -> ${module.ec2.terraria_server_elastic_ip}"
}

# SQS Access Credentials (stored in SSM)
output "sqs_access_key_id_parameter" {
  description = "SSM Parameter name for SQS Access Key ID"
  value       = module.iam.sqs_access_key_ssm_parameter
}

output "sqs_secret_access_key_parameter" {
  description = "SSM Parameter name for SQS Secret Access Key"
  value       = module.iam.sqs_secret_access_key_ssm_parameter
}

# SQS Access Credentials (actual values)
output "sqs_access_key_id" {
  description = "SQS Access Key ID"
  value       = module.iam.sqs_access_key_id
  sensitive   = true
}

output "sqs_secret_access_key" {
  description = "SQS Secret Access Key"
  value       = module.iam.sqs_secret_access_key
  sensitive   = true
}

# S3 Outputs
output "s3_docker_images_bucket_name" {
  description = "S3 bucket name for Docker images"
  value       = module.s3.bucket_name
}

output "s3_docker_images_bucket_arn" {
  description = "S3 bucket ARN for Docker images"
  value       = module.s3.bucket_arn
}

output "s3_image_maps_bucket_name" {
  description = "S3 bucket name for image maps"
  value       = module.s3.image_maps_bucket_name
}

output "s3_image_maps_bucket_arn" {
  description = "S3 bucket ARN for image maps"
  value       = module.s3.image_maps_bucket_arn
}

output "s3_vpc_endpoint_id" {
  description = "S3 VPC Endpoint ID"
  value       = module.vpc.s3_vpc_endpoint_id
}

output "s3_world_backups_bucket_name" {
  description = "S3 bucket name for world backups"
  value       = module.s3.world_backups_bucket_name
}

output "s3_world_backups_bucket_arn" {
  description = "S3 bucket ARN for world backups"
  value       = module.s3.world_backups_bucket_arn
}

output "s3_terraria_backups_bucket_name" {
  description = "S3 bucket name for terraria backups"
  value       = module.s3.terraria_backups_bucket_name
}

output "s3_terraria_backups_bucket_arn" {
  description = "S3 bucket ARN for terraria backups"
  value       = module.s3.terraria_backups_bucket_arn
}

# Lambda Outputs
output "ec2_scheduler_function_name" {
  description = "EC2 Scheduler Lambda function name"
  value       = module.lambda.ec2_scheduler_function_name
}

output "ec2_scheduler_function_arn" {
  description = "EC2 Scheduler Lambda function ARN"
  value       = module.lambda.ec2_scheduler_function_arn
}

# EventBridge Outputs
output "start_schedule_arn" {
  description = "EventBridge start schedule ARN"
  value       = module.eventbridge.start_schedule_arn
}

output "stop_schedule_arn" {
  description = "EventBridge stop schedule ARN"
  value       = module.eventbridge.stop_schedule_arn
}
