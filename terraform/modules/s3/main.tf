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

# ============================================================================
# Image Maps S3 Bucket (永続保存)
# ============================================================================

# S3 Bucket for Minecraft Image Maps
resource "aws_s3_bucket" "image_maps" {
  bucket = "kishax-${var.environment}-image-maps"

  tags = {
    Name        = "kishax-${var.environment}-image-maps"
    Environment = var.environment
    Purpose     = "Minecraft image maps storage - persistent"
  }
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "image_maps" {
  bucket = aws_s3_bucket.image_maps.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning
resource "aws_s3_bucket_versioning" "image_maps" {
  bucket = aws_s3_bucket.image_maps.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "image_maps" {
  bucket = aws_s3_bucket.image_maps.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# No lifecycle rule - keep images indefinitely

# Bucket policy to allow access from MC Server only
resource "aws_s3_bucket_policy" "image_maps" {
  bucket = aws_s3_bucket.image_maps.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowMCServerAccess"
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
          aws_s3_bucket.image_maps.arn,
          "${aws_s3_bucket.image_maps.arn}/*"
        ]
      },
      {
        Sid    = "DenyInsecureTransport"
        Effect = "Deny"
        Principal = "*"
        Action = "s3:*"
        Resource = [
          aws_s3_bucket.image_maps.arn,
          "${aws_s3_bucket.image_maps.arn}/*"
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

# ============================================================================
# World Backups S3 Bucket (永続保存 - バックアップ・VM展開・移植作業用)
# ============================================================================

# S3 Bucket for Minecraft World Backups
resource "aws_s3_bucket" "world_backups" {
  bucket = "kishax-${var.environment}-world-backups"

  tags = {
    Name        = "kishax-${var.environment}-world-backups"
    Environment = var.environment
    Purpose     = "Minecraft world backups and VM deployment"
  }
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "world_backups" {
  bucket = aws_s3_bucket.world_backups.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning
resource "aws_s3_bucket_versioning" "world_backups" {
  bucket = aws_s3_bucket.world_backups.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "world_backups" {
  bucket = aws_s3_bucket.world_backups.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Lifecycle rule - delete old backups and migration data
resource "aws_s3_bucket_lifecycle_configuration" "world_backups" {
  bucket = aws_s3_bucket.world_backups.id

  rule {
    id     = "delete-old-backups"
    status = "Enabled"

    filter {
      prefix = "backups/"
    }

    expiration {
      days = 180
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }

  # マイグレーション用のデータは90日で削除
  rule {
    id     = "delete-old-migration-data"
    status = "Enabled"

    filter {
      prefix = "migration/"
    }

    expiration {
      days = 90
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
  
  # 注: deployment/プレフィックスには自動削除ルールなし（永続保存）
}

# Bucket policy to allow access from MC Server (i-a)
resource "aws_s3_bucket_policy" "world_backups" {
  bucket = aws_s3_bucket.world_backups.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowMCServerAccess"
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
          aws_s3_bucket.world_backups.arn,
          "${aws_s3_bucket.world_backups.arn}/*"
        ]
      },
      {
        Sid    = "DenyInsecureTransport"
        Effect = "Deny"
        Principal = "*"
        Action = "s3:*"
        Resource = [
          aws_s3_bucket.world_backups.arn,
          "${aws_s3_bucket.world_backups.arn}/*"
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

# ============================================================================
# Terraria Backups S3 Bucket (永続保存 - バックアップ・VM展開用)
# ============================================================================

# S3 Bucket for Terraria Server Backups
resource "aws_s3_bucket" "terraria_backups" {
  bucket = "kishax-${var.environment}-terraria-backups"

  tags = {
    Name        = "kishax-${var.environment}-terraria-backups"
    Environment = var.environment
    Purpose     = "Terraria server backups and deployment"
  }
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "terraria_backups" {
  bucket = aws_s3_bucket.terraria_backups.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning
resource "aws_s3_bucket_versioning" "terraria_backups" {
  bucket = aws_s3_bucket.terraria_backups.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "terraria_backups" {
  bucket = aws_s3_bucket.terraria_backups.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Lifecycle rule - delete old backups
resource "aws_s3_bucket_lifecycle_configuration" "terraria_backups" {
  bucket = aws_s3_bucket.terraria_backups.id

  rule {
    id     = "delete-old-backups"
    status = "Enabled"

    filter {
      prefix = "backups/"
    }

    expiration {
      days = 180
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }

  # 注: deployment/プレフィックスには自動削除ルールなし（永続保存）
}

# Bucket policy to allow access from Terraria Server (i-e)
resource "aws_s3_bucket_policy" "terraria_backups" {
  bucket = aws_s3_bucket.terraria_backups.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowTerrariaServerAccess"
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
          aws_s3_bucket.terraria_backups.arn,
          "${aws_s3_bucket.terraria_backups.arn}/*"
        ]
      },
      {
        Sid    = "DenyInsecureTransport"
        Effect = "Deny"
        Principal = "*"
        Action = "s3:*"
        Resource = [
          aws_s3_bucket.terraria_backups.arn,
          "${aws_s3_bucket.terraria_backups.arn}/*"
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

# ============================================================================
# Environment Files S3 Bucket (.env専用 - 永続保存)
# ============================================================================

# S3 Bucket for Environment Files (.env)
resource "aws_s3_bucket" "env_files" {
  bucket = "kishax-${var.environment}-env-files"

  tags = {
    Name        = "kishax-${var.environment}-env-files"
    Environment = var.environment
    Purpose     = "Environment files (.env) storage - encrypted and persistent"
  }
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "env_files" {
  bucket = aws_s3_bucket.env_files.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning
resource "aws_s3_bucket_versioning" "env_files" {
  bucket = aws_s3_bucket.env_files.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "env_files" {
  bucket = aws_s3_bucket.env_files.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# No lifecycle rule - keep .env files indefinitely

# Bucket policy to allow read access from all EC2 instances
resource "aws_s3_bucket_policy" "env_files" {
  bucket = aws_s3_bucket.env_files.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEC2InstancesReadAccess"
        Effect = "Allow"
        Principal = {
          AWS = var.ec2_instance_role_arns
        }
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.env_files.arn,
          "${aws_s3_bucket.env_files.arn}/*"
        ]
      },
      {
        Sid    = "DenyInsecureTransport"
        Effect = "Deny"
        Principal = "*"
        Action = "s3:*"
        Resource = [
          aws_s3_bucket.env_files.arn,
          "${aws_s3_bucket.env_files.arn}/*"
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
