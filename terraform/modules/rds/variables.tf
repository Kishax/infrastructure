# RDS Module - Variables

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for RDS"
  type        = list(string)
}

variable "rds_security_group_id" {
  description = "RDS Security Group ID"
  type        = string
}

# PostgreSQL Variables
variable "postgres_instance_class" {
  description = "PostgreSQL instance class"
  type        = string
}

variable "postgres_allocated_storage" {
  description = "PostgreSQL allocated storage in GB"
  type        = number
}

variable "postgres_db_name" {
  description = "PostgreSQL database name"
  type        = string
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

# MySQL Variables
variable "mysql_instance_class" {
  description = "MySQL instance class"
  type        = string
}

variable "mysql_allocated_storage" {
  description = "MySQL allocated storage in GB"
  type        = number
}

variable "mysql_db_name" {
  description = "MySQL database name"
  type        = string
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
