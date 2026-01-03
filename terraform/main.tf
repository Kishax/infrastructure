# Kishax Infrastructure - Terraform Main Configuration
# EC2ベースのコスト最適化インフラストラクチャ

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # S3バックエンド設定（必要に応じて有効化）
  # backend "s3" {
  #   bucket         = "kishax-terraform-state"
  #   key            = "infrastructure/terraform.tfstate"
  #   region         = "ap-northeast-1"
  #   encrypt        = true
  #   dynamodb_table = "kishax-terraform-locks"
  # }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = {
      Project     = "Kishax"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# VPC Module
module "vpc" {
  source = "./modules/vpc"

  environment = var.environment
  vpc_cidr    = var.vpc_cidr
  aws_region  = var.aws_region
}

# Security Groups Module
module "security_groups" {
  source = "./modules/security_groups"

  environment = var.environment
  vpc_id      = module.vpc.vpc_id
}

# S3 Module (Docker Images Storage)
module "s3" {
  source = "./modules/s3"

  environment            = var.environment
  vpc_id                 = module.vpc.vpc_id
  ec2_instance_role_arns = module.iam.all_ec2_role_arns
}

# IAM Module
module "iam" {
  source = "./modules/iam"

  environment                 = var.environment
  route53_zone_id             = var.route53_zone_id
  mc_domain_name              = var.mc_domain_name
  s3_docker_images_bucket_arn = module.s3.bucket_arn
  s3_image_maps_bucket_arn    = module.s3.image_maps_bucket_arn
  s3_world_backups_bucket_arn = module.s3.world_backups_bucket_arn
  s3_env_files_bucket_arn     = module.s3.env_files_bucket_arn
}

# RDS Module
module "rds" {
  source = "./modules/rds"

  environment           = var.environment
  vpc_id                = module.vpc.vpc_id
  private_subnet_ids    = module.vpc.private_subnet_ids
  rds_security_group_id = module.security_groups.rds_security_group_id

  # PostgreSQL
  postgres_instance_class    = var.postgres_instance_class
  postgres_allocated_storage = var.postgres_allocated_storage
  postgres_db_name           = var.postgres_db_name
  postgres_username          = var.postgres_username
  postgres_password          = var.postgres_password

  # MySQL
  mysql_instance_class    = var.mysql_instance_class
  mysql_allocated_storage = var.mysql_allocated_storage
  mysql_db_name           = var.mysql_db_name
  mysql_username          = var.mysql_username
  mysql_password          = var.mysql_password
}

# SQS Module
module "sqs" {
  source = "./modules/sqs"

  environment = var.environment
}

# SSM Parameter Store Module
module "ssm" {
  source = "./modules/ssm"

  environment = var.environment
  aws_region  = var.aws_region

  # Shared Parameters
  sqs_access_key_id      = var.sqs_access_key_id
  sqs_secret_access_key  = var.sqs_secret_access_key
  to_web_queue_url       = module.sqs.to_web_queue_url
  to_mc_queue_url        = module.sqs.to_mc_queue_url
  to_discord_queue_url   = module.sqs.discord_queue_url
  mysql_host             = module.rds.mysql_endpoint
  mysql_database         = var.mysql_db_name
  mysql_user             = var.mysql_username
  mysql_password         = var.mysql_password
  postgres_host          = module.rds.postgres_endpoint
  postgres_database      = var.postgres_db_name
  postgres_user          = var.postgres_username
  postgres_password      = var.postgres_password
  auth_api_key           = var.auth_api_key

  # MC Server Parameters
  mc_overall_memory                        = var.mc_overall_memory
  mc_seed_env                              = var.mc_seed_env
  mc_confirm_base_url                      = var.mc_confirm_base_url
  mc_redis_connection_timeout              = "5000"
  mc_redis_command_timeout                 = "3000"
  mc_queue_mode                            = "MC"
  mc_sqs_worker_enabled                    = "true"
  mc_sqs_worker_polling_interval_seconds   = "5"
  mc_sqs_worker_max_messages               = "10"
  mc_sqs_worker_wait_time_seconds          = "20"
  mc_sqs_worker_visibility_timeout_seconds = "30"
  mc_log_level                             = "INFO"
  mc_kishax_api_branch                     = var.mc_kishax_api_branch

  # Web Server Parameters
  web_queue_mode                = "WEB"
  web_sqs_worker_enabled        = "false"
  web_nextauth_url              = "https://${var.web_domain_name}"
  web_nextauth_secret           = var.web_nextauth_secret
  web_google_client_id          = var.web_google_client_id
  web_google_client_secret      = var.web_google_client_secret
  web_discord_client_id         = var.web_discord_client_id
  web_discord_client_secret     = var.web_discord_client_secret
  web_twitter_client_id         = var.web_twitter_client_id
  web_twitter_client_secret     = var.web_twitter_client_secret
  web_email_host                = var.web_email_host
  web_email_port                = "587"
  web_email_user                = var.web_email_user
  web_email_pass                = var.web_email_pass
  web_email_from                = var.web_email_from
  web_node_env                  = "production"
  web_port                      = "80"
  web_log_level                 = "info"
  web_internal_api_key          = var.web_internal_api_key
  web_redis_connection_timeout  = "5000"
  web_redis_command_timeout     = "3000"

  # API Server Parameters
  api_redis_url_discord              = "redis://redis-mc:6379"
  api_auth_api_enabled               = "true"
  api_auth_api_port                  = "8080"
  api_discord_token                  = var.api_discord_token
  api_discord_channel_id             = var.api_discord_channel_id
  api_discord_chat_channel_id        = var.api_discord_chat_channel_id
  api_discord_admin_channel_id       = var.api_discord_admin_channel_id
  api_discord_rule_channel_id        = var.api_discord_rule_channel_id
  api_discord_rule_message_id        = var.api_discord_rule_message_id
  api_discord_guild_id               = var.api_discord_guild_id
  api_discord_presence_activity      = "↑mc.kishax.net↑"
  api_be_default_emoji_name          = "steve"
  api_aws_sqs_max_messages           = "10"
  api_aws_sqs_wait_time_seconds      = "20"
  api_sqs_worker_polling_interval    = "5"
  api_sqs_worker_max_messages        = "10"
  api_sqs_worker_wait_time            = "20"
  api_sqs_worker_visibility_timeout  = "300"
  api_shutdown_grace_period          = "10"
  api_log_level                      = "INFO"

  # Terraria Server Parameters
  terraria_s3_bucket           = var.terraria_s3_bucket
  terraria_s3_download_enabled = "true"
  terraria_server_password     = var.terraria_server_password
  terraria_server_port         = "7777"
  terraria_max_slots           = "8"
  terraria_server_name         = "Kishax Terraria Server"
  terraria_discord_bot_token   = var.terraria_discord_bot_token
  terraria_discord_channel_id  = var.terraria_discord_channel_id
  terraria_rest_api_enabled    = "true"
  terraria_rest_api_port       = "7878"
  terraria_rest_api_token      = var.terraria_rest_api_token
  terraria_rest_api_username   = "admin"
  terraria_rest_api_usergroup  = "superadmin"

  tags = {
    Module = "SSM"
  }
}

# EC2 Instances Module
module "ec2" {
  source = "./modules/ec2"

  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.vpc.public_subnet_ids
  private_subnet_ids = module.vpc.private_subnet_ids

  # Security Groups
  mc_server_sg_id       = module.security_groups.mc_server_sg_id
  api_server_sg_id      = module.security_groups.api_server_sg_id
  web_server_sg_id      = module.security_groups.web_server_sg_id
  jump_server_sg_id     = module.security_groups.jump_server_sg_id
  terraria_server_sg_id = module.security_groups.terraria_server_sg_id

  # IAM Roles
  mc_server_instance_profile       = module.iam.mc_server_instance_profile_name
  api_server_instance_profile      = module.iam.api_server_instance_profile_name
  web_server_instance_profile      = module.iam.web_server_instance_profile_name
  jump_server_instance_profile     = module.iam.jump_server_instance_profile_name
  terraria_server_instance_profile = module.iam.terraria_server_instance_profile_name

  # RDS Endpoints
  postgres_endpoint = module.rds.postgres_endpoint
  mysql_endpoint    = module.rds.mysql_endpoint

  # SQS Queue URLs
  to_mc_queue_url   = module.sqs.to_mc_queue_url
  to_web_queue_url  = module.sqs.to_web_queue_url
  discord_queue_url = module.sqs.discord_queue_url

  # Route53
  route53_zone_id = var.route53_zone_id
  mc_domain_name  = var.mc_domain_name
  web_domain_name = var.web_domain_name

  # EC2 Key Pair
  ec2_key_pair_name = var.ec2_key_pair_name
}

# CloudFront Module
module "cloudfront" {
  source = "./modules/cloudfront"

  environment           = var.environment
  web_server_public_dns = module.ec2.web_server_public_dns
  web_domain_name       = var.web_domain_name
  acm_certificate_arn   = var.acm_certificate_arn
}

# Route53 Module
module "route53" {
  source = "./modules/route53"

  environment     = var.environment
  route53_zone_id = var.route53_zone_id

  # MC Server (動的に更新されるため、初期値のみ設定)
  mc_domain_name       = var.mc_domain_name
  mc_server_elastic_ip = module.ec2.mc_server_elastic_ip

  # Web (CloudFront経由)
  web_domain_name        = var.web_domain_name
  cloudfront_domain_name = module.cloudfront.cloudfront_domain_name
  cloudfront_zone_id     = module.cloudfront.cloudfront_zone_id

  # Terraria Server
  terraria_domain_name         = var.terraria_domain_name
  terraria_server_elastic_ip   = module.ec2.terraria_server_elastic_ip
}

# Lambda Module - EC2 Scheduler
module "lambda" {
  source = "./modules/lambda"

  environment = var.environment
}

# EventBridge Module - EC2 Scheduler
module "eventbridge" {
  source = "./modules/eventbridge"

  environment            = var.environment
  lambda_function_arn    = module.lambda.ec2_scheduler_function_arn
  mc_server_instance_id  = module.ec2.mc_server_instance_id
  api_server_instance_id = module.ec2.api_server_instance_id
  web_server_instance_id = module.ec2.web_server_instance_id
}
