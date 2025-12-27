# S3 Module Variables

variable "environment" {
  description = "Environment name (e.g., production, staging)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for VPC Endpoint"
  type        = string
}

variable "ec2_instance_role_arns" {
  description = "List of EC2 instance role ARNs that need S3 access"
  type        = list(string)
}
