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
  
  environment                = var.environment
  vpc_id                     = module.vpc.vpc_id
  ec2_instance_role_arns     = module.iam.all_ec2_role_arns
}

# IAM Module
module "iam" {
  source = "./modules/iam"
  
  environment                 = var.environment
  route53_zone_id             = var.route53_zone_id
  mc_domain_name              = var.mc_domain_name
  s3_docker_images_bucket_arn = module.s3.bucket_arn
  s3_image_maps_bucket_arn    = module.s3.image_maps_bucket_arn
}

# RDS Module
module "rds" {
  source = "./modules/rds"
  
  environment              = var.environment
  vpc_id                   = module.vpc.vpc_id
  private_subnet_ids       = module.vpc.private_subnet_ids
  rds_security_group_id    = module.security_groups.rds_security_group_id
  
  # PostgreSQL
  postgres_instance_class  = var.postgres_instance_class
  postgres_allocated_storage = var.postgres_allocated_storage
  postgres_db_name         = var.postgres_db_name
  postgres_username        = var.postgres_username
  postgres_password        = var.postgres_password
  
  # MySQL
  mysql_instance_class     = var.mysql_instance_class
  mysql_allocated_storage  = var.mysql_allocated_storage
  mysql_db_name            = var.mysql_db_name
  mysql_username           = var.mysql_username
  mysql_password           = var.mysql_password
}

# SQS Module
module "sqs" {
  source = "./modules/sqs"
  
  environment = var.environment
}

# EC2 Instances Module
module "ec2" {
  source = "./modules/ec2"
  
  environment               = var.environment
  vpc_id                    = module.vpc.vpc_id
  public_subnet_ids         = module.vpc.public_subnet_ids
  private_subnet_ids        = module.vpc.private_subnet_ids
  
  # Security Groups
  mc_server_sg_id           = module.security_groups.mc_server_sg_id
  api_server_sg_id          = module.security_groups.api_server_sg_id
  web_server_sg_id          = module.security_groups.web_server_sg_id
  jump_server_sg_id         = module.security_groups.jump_server_sg_id
  
  # IAM Roles
  mc_server_instance_profile   = module.iam.mc_server_instance_profile_name
  api_server_instance_profile  = module.iam.api_server_instance_profile_name
  web_server_instance_profile  = module.iam.web_server_instance_profile_name
  jump_server_instance_profile = module.iam.jump_server_instance_profile_name
  
  # RDS Endpoints
  postgres_endpoint         = module.rds.postgres_endpoint
  mysql_endpoint            = module.rds.mysql_endpoint
  
  # SQS Queue URLs
  to_mc_queue_url           = module.sqs.to_mc_queue_url
  to_web_queue_url          = module.sqs.to_web_queue_url
  discord_queue_url         = module.sqs.discord_queue_url
  
  # Route53
  route53_zone_id           = var.route53_zone_id
  mc_domain_name            = var.mc_domain_name
  
  # EC2 Key Pair
  ec2_key_pair_name         = var.ec2_key_pair_name
}

# CloudFront Module
module "cloudfront" {
  source = "./modules/cloudfront"
  
  environment              = var.environment
  web_server_public_dns    = module.ec2.web_server_public_dns
  web_domain_name          = var.web_domain_name
  acm_certificate_arn      = var.acm_certificate_arn
}

# Route53 Module
module "route53" {
  source = "./modules/route53"
  
  environment              = var.environment
  route53_zone_id          = var.route53_zone_id
  
  # MC Server (動的に更新されるため、初期値のみ設定)
  mc_domain_name           = var.mc_domain_name
  mc_server_elastic_ip     = module.ec2.mc_server_elastic_ip
  
  # Web (CloudFront経由)
  web_domain_name          = var.web_domain_name
  cloudfront_domain_name   = module.cloudfront.cloudfront_domain_name
  cloudfront_zone_id       = module.cloudfront.cloudfront_zone_id
}
