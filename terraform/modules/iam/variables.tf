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

variable "s3_docker_images_bucket_arn" {
  description = "S3 bucket ARN for Docker images"
  type        = string
}

variable "s3_image_maps_bucket_arn" {
  description = "S3 bucket ARN for image maps"
  type        = string
}

variable "s3_world_backups_bucket_arn" {
  description = "S3 bucket ARN for world backups"
  type        = string
}
