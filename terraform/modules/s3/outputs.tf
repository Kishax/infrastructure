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

# Terraria Backups Bucket
output "terraria_backups_bucket_name" {
  description = "S3 bucket name for terraria backups"
  value       = aws_s3_bucket.terraria_backups.id
}

output "terraria_backups_bucket_arn" {
  description = "S3 bucket ARN for terraria backups"
  value       = aws_s3_bucket.terraria_backups.arn
}

output "terraria_backups_bucket_regional_domain_name" {
  description = "S3 bucket regional domain name for terraria backups"
  value       = aws_s3_bucket.terraria_backups.bucket_regional_domain_name
}

# Environment Files Bucket
output "env_files_bucket_name" {
  description = "S3 bucket name for environment files (.env)"
  value       = aws_s3_bucket.env_files.id
}

output "env_files_bucket_arn" {
  description = "S3 bucket ARN for environment files"
  value       = aws_s3_bucket.env_files.arn
}

output "env_files_bucket_regional_domain_name" {
  description = "S3 bucket regional domain name for environment files"
  value       = aws_s3_bucket.env_files.bucket_regional_domain_name
}
