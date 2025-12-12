# IAM Module - Variables

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "route53_zone_id" {
  description = "Route53 Hosted Zone ID for Route53 update permission"
  type        = string
}

variable "mc_domain_name" {
  description = "Minecraft server domain name"
  type        = string
}
