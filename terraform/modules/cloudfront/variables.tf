# CloudFront Module - Variables

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "web_server_public_ip" {
  description = "Web Server Public IP address"
  type        = string
}

variable "web_domain_name" {
  description = "Web application domain name"
  type        = string
}

variable "acm_certificate_arn" {
  description = "ACM Certificate ARN for CloudFront (must be in us-east-1)"
  type        = string
}
