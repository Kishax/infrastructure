# Kishax Infrastructure - Variables

variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "ap-northeast-1"
}

variable "aws_profile" {
  description = "AWS CLI Profile"
  type        = string
  default     = "AdministratorAccess-126112056177"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

# VPC Configuration
variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

# Route53 Configuration
variable "route53_zone_id" {
  description = "Route53 Hosted Zone ID for kishax.net"
  type        = string
}

variable "mc_domain_name" {
  description = "Minecraft server domain name"
  type        = string
  default     = "mc.kishax.net"
}

variable "web_domain_name" {
  description = "Web application domain name"
  type        = string
  default     = "kishax.net"
}

variable "terraria_domain_name" {
  description = "Terraria server domain name"
  type        = string
  default     = "tera.kishax.net"
}

# RDS PostgreSQL Configuration
variable "postgres_instance_class" {
  description = "PostgreSQL RDS instance class"
  type        = string
  default     = "db.t4g.micro"
}

variable "postgres_allocated_storage" {
  description = "PostgreSQL allocated storage in GB"
  type        = number
  default     = 20
}

variable "postgres_db_name" {
  description = "PostgreSQL database name"
  type        = string
  default     = "kishax_main"
}

variable "postgres_username" {
  description = "PostgreSQL master username"
  type        = string
  sensitive   = true
}

variable "postgres_password" {
  description = "PostgreSQL master password"
  type        = string
  sensitive   = true
}

# RDS MySQL Configuration
variable "mysql_instance_class" {
  description = "MySQL RDS instance class"
  type        = string
  default     = "db.t4g.micro"
}

variable "mysql_allocated_storage" {
  description = "MySQL allocated storage in GB"
  type        = number
  default     = 20
}

variable "mysql_db_name" {
  description = "MySQL database name"
  type        = string
  default     = "kishax_mc"
}

variable "mysql_username" {
  description = "MySQL master username"
  type        = string
  sensitive   = true
}

variable "mysql_password" {
  description = "MySQL master password"
  type        = string
  sensitive   = true
}

# CloudFront Configuration
variable "acm_certificate_arn" {
  description = "ACM Certificate ARN for CloudFront (us-east-1)"
  type        = string
}

# EC2 Key Pair
variable "ec2_key_pair_name" {
  description = "EC2 key pair name for SSH access"
  type        = string
}

# ===================================
# SSM Parameter Store Variables
# ===================================

# Shared Parameters
variable "sqs_access_key_id" {
  description = "SQS Access Key ID"
  type        = string
}

variable "sqs_secret_access_key" {
  description = "SQS Secret Access Key"
  type        = string
  sensitive   = true
}

variable "to_web_queue_url" {
  description = "SQS Queue URL for to-web queue"
  type        = string
}

variable "to_mc_queue_url" {
  description = "SQS Queue URL for to-mc queue"
  type        = string
}

variable "to_discord_queue_url" {
  description = "SQS Queue URL for to-discord queue"
  type        = string
}

variable "auth_api_key" {
  description = "Auth API Key"
  type        = string
  sensitive   = true
}

# MC Server Parameters
variable "mc_overall_memory" {
  description = "MC Server overall memory allocation"
  type        = string
  default     = "8.0"
}

variable "mc_seed_env" {
  description = "MC Server seed environment"
  type        = string
  default     = "production"
}

variable "mc_confirm_base_url" {
  description = "MC Confirm Base URL"
  type        = string
  default     = "https://kishax.net"
}

variable "mc_kishax_api_branch" {
  description = "Kishax API branch for MC"
  type        = string
  default     = "master"
}

# Web Server Parameters
variable "web_nextauth_secret" {
  description = "NextAuth secret"
  type        = string
  sensitive   = true
}

variable "web_google_client_id" {
  description = "Google OAuth Client ID"
  type        = string
}

variable "web_google_client_secret" {
  description = "Google OAuth Client Secret"
  type        = string
  sensitive   = true
}

variable "web_discord_client_id" {
  description = "Discord OAuth Client ID"
  type        = string
}

variable "web_discord_client_secret" {
  description = "Discord OAuth Client Secret"
  type        = string
  sensitive   = true
}

variable "web_twitter_client_id" {
  description = "Twitter OAuth Client ID"
  type        = string
}

variable "web_twitter_client_secret" {
  description = "Twitter OAuth Client Secret"
  type        = string
  sensitive   = true
}

variable "web_email_host" {
  description = "Email SMTP host"
  type        = string
}

variable "web_email_user" {
  description = "Email SMTP user"
  type        = string
}

variable "web_email_pass" {
  description = "Email SMTP password"
  type        = string
  sensitive   = true
}

variable "web_email_from" {
  description = "Email from address"
  type        = string
}

variable "web_internal_api_key" {
  description = "Internal API key for Web"
  type        = string
  sensitive   = true
}

# API Server Parameters
variable "api_discord_token" {
  description = "Discord bot token"
  type        = string
  sensitive   = true
}

variable "api_discord_channel_id" {
  description = "Discord channel ID"
  type        = string
}

variable "api_discord_chat_channel_id" {
  description = "Discord chat channel ID"
  type        = string
}

variable "api_discord_admin_channel_id" {
  description = "Discord admin channel ID"
  type        = string
}

variable "api_discord_rule_channel_id" {
  description = "Discord rule channel ID"
  type        = string
}

variable "api_discord_rule_message_id" {
  description = "Discord rule message ID"
  type        = string
}

variable "api_discord_guild_id" {
  description = "Discord guild ID"
  type        = string
}

# Terraria Server Parameters
variable "terraria_s3_bucket" {
  description = "S3 bucket for Terraria backups"
  type        = string
}

variable "terraria_server_password" {
  description = "Terraria server password"
  type        = string
  sensitive   = true
}

variable "terraria_discord_bot_token" {
  description = "Terraria Discord bot token"
  type        = string
  sensitive   = true
}

variable "terraria_discord_channel_id" {
  description = "Terraria Discord channel ID"
  type        = string
}

variable "terraria_rest_api_token" {
  description = "Terraria REST API token"
  type        = string
  sensitive   = true
}
