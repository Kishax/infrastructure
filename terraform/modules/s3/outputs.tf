# S3 Module Outputs

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
