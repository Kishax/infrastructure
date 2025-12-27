# CloudFront Module - Variables

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "web_server_public_ip" {
  description = "Web Server Public IP address (deprecated, use public_dns)"
  type        = string
  default     = ""
}

variable "web_server_public_dns" {
  description = "Web Server Public DNS name"
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
