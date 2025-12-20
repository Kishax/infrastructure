# S3 Module Outputs

# Docker Images Bucket
output "bucket_name" {
  description = "S3 bucket name for Docker images"
  value       = aws_s3_bucket.docker_images.id
}

output "bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.docker_images.arn
}

output "bucket_regional_domain_name" {
  description = "S3 bucket regional domain name"
  value       = aws_s3_bucket.docker_images.bucket_regional_domain_name
}

# Image Maps Bucket
output "image_maps_bucket_name" {
  description = "S3 bucket name for image maps"
  value       = aws_s3_bucket.image_maps.id
}

output "image_maps_bucket_arn" {
  description = "S3 bucket ARN for image maps"
  value       = aws_s3_bucket.image_maps.arn
}

output "image_maps_bucket_regional_domain_name" {
  description = "S3 bucket regional domain name for image maps"
  value       = aws_s3_bucket.image_maps.bucket_regional_domain_name
}

# World Backups Bucket
output "world_backups_bucket_name" {
  description = "S3 bucket name for world backups"
  value       = aws_s3_bucket.world_backups.id
}

output "world_backups_bucket_arn" {
  description = "S3 bucket ARN for world backups"
  value       = aws_s3_bucket.world_backups.arn
}

output "world_backups_bucket_regional_domain_name" {
  description = "S3 bucket regional domain name for world backups"
  value       = aws_s3_bucket.world_backups.bucket_regional_domain_name
}
