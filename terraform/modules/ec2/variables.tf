# EC2 Module - Variables

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
}

# Security Groups
variable "mc_server_sg_id" {
  description = "MC Server Security Group ID"
  type        = string
}

variable "api_server_sg_id" {
  description = "API Server Security Group ID"
  type        = string
}

variable "web_server_sg_id" {
  description = "Web Server Security Group ID"
  type        = string
}

variable "jump_server_sg_id" {
  description = "Jump Server Security Group ID"
  type        = string
}

variable "terraria_server_sg_id" {
  description = "Terraria Server Security Group ID"
  type        = string
}

# IAM Instance Profiles
variable "mc_server_instance_profile" {
  description = "MC Server IAM Instance Profile Name"
  type        = string
}

variable "api_server_instance_profile" {
  description = "API Server IAM Instance Profile Name"
  type        = string
}

variable "web_server_instance_profile" {
  description = "Web Server IAM Instance Profile Name"
  type        = string
}

variable "jump_server_instance_profile" {
  description = "Jump Server IAM Instance Profile Name"
  type        = string
}

variable "terraria_server_instance_profile" {
  description = "Terraria Server IAM Instance Profile Name"
  type        = string
}

# RDS Endpoints
variable "postgres_endpoint" {
  description = "PostgreSQL RDS endpoint"
  type        = string
}

variable "mysql_endpoint" {
  description = "MySQL RDS endpoint"
  type        = string
}

# SQS Queue URLs
variable "to_mc_queue_url" {
  description = "TO MC Queue URL"
  type        = string
}

variable "to_web_queue_url" {
  description = "TO WEB Queue URL"
  type        = string
}

variable "discord_queue_url" {
  description = "Discord Queue URL"
  type        = string
}

# Route53
variable "route53_zone_id" {
  description = "Route53 Hosted Zone ID"
  type        = string
}

variable "mc_domain_name" {
  description = "Minecraft server domain name"
  type        = string
}

variable "web_domain_name" {
  description = "Web server domain name"
  type        = string
}

variable "ec2_key_pair_name" {
  description = "EC2 key pair name for SSH access"
  type        = string
  default     = ""
}
