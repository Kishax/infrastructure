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
