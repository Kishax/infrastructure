# S3 Module - Docker Images Storage

# S3 Bucket for Docker Images
resource "aws_s3_bucket" "docker_images" {
  bucket = "kishax-${var.environment}-docker-images"

  tags = {
    Name        = "kishax-${var.environment}-docker-images"
    Environment = var.environment
    Purpose     = "Docker image storage for deployment"
  }
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "docker_images" {
  bucket = aws_s3_bucket.docker_images.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning
resource "aws_s3_bucket_versioning" "docker_images" {
  bucket = aws_s3_bucket.docker_images.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "docker_images" {
  bucket = aws_s3_bucket.docker_images.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Lifecycle rule - delete old images after 30 days
resource "aws_s3_bucket_lifecycle_configuration" "docker_images" {
  bucket = aws_s3_bucket.docker_images.id

  rule {
    id     = "delete-old-images"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = 30
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}

# Bucket policy to allow access from VPC Endpoint only
resource "aws_s3_bucket_policy" "docker_images" {
  bucket = aws_s3_bucket.docker_images.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowVPCEndpointAccess"
        Effect = "Allow"
        Principal = {
          AWS = var.ec2_instance_role_arns
        }
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.docker_images.arn,
          "${aws_s3_bucket.docker_images.arn}/*"
        ]
      },
      {
        Sid    = "DenyInsecureTransport"
        Effect = "Deny"
        Principal = "*"
        Action = "s3:*"
        Resource = [
          aws_s3_bucket.docker_images.arn,
          "${aws_s3_bucket.docker_images.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}
