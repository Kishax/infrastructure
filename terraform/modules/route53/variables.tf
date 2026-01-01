# Route53 Module - Variables

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "route53_zone_id" {
  description = "Route53 Hosted Zone ID"
  type        = string
}

# MC Server
variable "mc_domain_name" {
  description = "Minecraft server domain name"
  type        = string
}

variable "mc_server_elastic_ip" {
  description = "MC Server Elastic IP"
  type        = string
}

# Web Application
variable "web_domain_name" {
  description = "Web application domain name"
  type        = string
  default     = ""  # オプショナル
}

variable "cloudfront_domain_name" {
  description = "CloudFront Distribution Domain Name"
  type        = string
  default     = ""  # オプショナル
}

variable "cloudfront_zone_id" {
  description = "CloudFront Distribution Hosted Zone ID"
  type        = string
  default     = ""  # オプショナル
}

# Terraria Server
variable "terraria_domain_name" {
  description = "Terraria server domain name"
  type        = string
  default     = ""  # オプショナル
}

variable "terraria_server_elastic_ip" {
  description = "Terraria Server Elastic IP"
  type        = string
  default     = ""  # オプショナル
}
