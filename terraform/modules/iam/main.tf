# IAM Module - Main Configuration

# MC Server IAM Role (i-a) - Route53更新権限
resource "aws_iam_role" "mc_server" {
  name = "kishax-${var.environment}-mc-server-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name     = "kishax-${var.environment}-mc-server-role"
    Instance = "i-a"
  }
}

# MC Server Policy - Route53 Update
resource "aws_iam_role_policy" "mc_server_route53" {
  name = "kishax-${var.environment}-mc-route53-policy"
  role = aws_iam_role.mc_server.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets"
        ]
        Resource = "arn:aws:route53:::hostedzone/${var.route53_zone_id}"
      },
      {
        Effect = "Allow"
        Action = [
          "route53:GetChange"
        ]
        Resource = "*"
      }
    ]
  })
}

# MC Server Policy - SSM Access
resource "aws_iam_role_policy" "mc_server_ssm" {
  name = "kishax-${var.environment}-mc-ssm-policy"
  role = aws_iam_role.mc_server.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = "arn:aws:ssm:*:*:parameter/kishax/*"
      }
    ]
  })
}

# MC Server Policy - SSM Session Manager
resource "aws_iam_role_policy_attachment" "mc_server_ssm_session" {
  role       = aws_iam_role.mc_server.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# MC Server Policy - S3 Access (Docker Images, World Data, Image Maps, World Backups, Env Files)
resource "aws_iam_role_policy" "mc_server_s3" {
  name = "kishax-${var.environment}-mc-s3-policy"
  role = aws_iam_role.mc_server.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:HeadObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.s3_docker_images_bucket_arn,
          "${var.s3_docker_images_bucket_arn}/*",
          var.s3_image_maps_bucket_arn,
          "${var.s3_image_maps_bucket_arn}/*",
          var.s3_world_backups_bucket_arn,
          "${var.s3_world_backups_bucket_arn}/*"
        ]
      }
    ]
  })
}

# MC Server Instance Profile
resource "aws_iam_instance_profile" "mc_server" {
  name = "kishax-${var.environment}-mc-server-profile"
  role = aws_iam_role.mc_server.name
}

# API Server IAM Role (i-b) - SQS, RDS, SSM
resource "aws_iam_role" "api_server" {
  name = "kishax-${var.environment}-api-server-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name     = "kishax-${var.environment}-api-server-role"
    Instance = "i-b"
  }
}

# API Server Policy - SQS Access
resource "aws_iam_role_policy" "api_server_sqs" {
  name = "kishax-${var.environment}-api-sqs-policy"
  role = aws_iam_role.api_server.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = "arn:aws:sqs:*:*:kishax-*"
      }
    ]
  })
}

# API Server Policy - SSM Access
resource "aws_iam_role_policy" "api_server_ssm" {
  name = "kishax-${var.environment}-api-ssm-policy"
  role = aws_iam_role.api_server.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath",
          "ssm:PutParameter"
        ]
        Resource = "arn:aws:ssm:*:*:parameter/kishax/*"
      }
    ]
  })
}

# API Server Policy - SSM Session Manager
resource "aws_iam_role_policy_attachment" "api_server_ssm_session" {
  role       = aws_iam_role.api_server.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# API Server Policy - S3 Access (Docker Images, Env Files)
resource "aws_iam_role_policy" "api_server_s3" {
  name = "kishax-${var.environment}-api-s3-policy"
  role = aws_iam_role.api_server.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.s3_docker_images_bucket_arn,
          "${var.s3_docker_images_bucket_arn}/*"
        ]
      }
    ]
  })
}

# API Server Instance Profile
resource "aws_iam_instance_profile" "api_server" {
  name = "kishax-${var.environment}-api-server-profile"
  role = aws_iam_role.api_server.name
}

# Web Server IAM Role (i-c) - SQS, RDS, SSM
resource "aws_iam_role" "web_server" {
  name = "kishax-${var.environment}-web-server-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name     = "kishax-${var.environment}-web-server-role"
    Instance = "i-c"
  }
}

# Web Server Policy - SQS Access
resource "aws_iam_role_policy" "web_server_sqs" {
  name = "kishax-${var.environment}-web-sqs-policy"
  role = aws_iam_role.web_server.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = "arn:aws:sqs:*:*:kishax-*"
      }
    ]
  })
}

# Web Server Policy - SSM Access
resource "aws_iam_role_policy" "web_server_ssm" {
  name = "kishax-${var.environment}-web-ssm-policy"
  role = aws_iam_role.web_server.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = "arn:aws:ssm:*:*:parameter/kishax/*"
      }
    ]
  })
}

# Web Server Policy - SSM Session Manager
resource "aws_iam_role_policy_attachment" "web_server_ssm_session" {
  role       = aws_iam_role.web_server.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Web Server Policy - Route53 Update
resource "aws_iam_role_policy" "web_server_route53" {
  name = "kishax-${var.environment}-web-route53-policy"
  role = aws_iam_role.web_server.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets"
        ]
        Resource = "arn:aws:route53:::hostedzone/${var.route53_zone_id}"
      },
      {
        Effect = "Allow"
        Action = [
          "route53:GetChange"
        ]
        Resource = "*"
      }
    ]
  })
}

# Web Server Policy - S3 Access (Docker Images, Env Files)
resource "aws_iam_role_policy" "web_server_s3" {
  name = "kishax-${var.environment}-web-s3-policy"
  role = aws_iam_role.web_server.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.s3_docker_images_bucket_arn,
          "${var.s3_docker_images_bucket_arn}/*"
        ]
      }
    ]
  })
}

# Web Server Instance Profile
resource "aws_iam_instance_profile" "web_server" {
  name = "kishax-${var.environment}-web-server-profile"
  role = aws_iam_role.web_server.name
}

# Jump Server IAM Role (i-d) - SSM Session Manager
resource "aws_iam_role" "jump_server" {
  name = "kishax-${var.environment}-jump-server-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name     = "kishax-${var.environment}-jump-server-role"
    Instance = "i-d"
  }
}

# Jump Server Policy - SSM Session Manager
resource "aws_iam_role_policy_attachment" "jump_server_ssm" {
  role       = aws_iam_role.jump_server.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Jump Server Instance Profile
resource "aws_iam_instance_profile" "jump_server" {
  name = "kishax-${var.environment}-jump-server-profile"
  role = aws_iam_role.jump_server.name
}

# Terraria Server IAM Role (i-e) - SSM Session Manager
resource "aws_iam_role" "terraria_server" {
  name = "kishax-${var.environment}-terraria-server-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name     = "kishax-${var.environment}-terraria-server-role"
    Instance = "i-e"
  }
}

# Terraria Server Policy - SSM Session Manager
resource "aws_iam_role_policy_attachment" "terraria_server_ssm" {
  role       = aws_iam_role.terraria_server.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Terraria Server Instance Profile
resource "aws_iam_instance_profile" "terraria_server" {
  name = "kishax-${var.environment}-terraria-server-profile"
  role = aws_iam_role.terraria_server.name
}

# ============================================================================
# SQS Access User (Docker containers用)
# ============================================================================

# SQS Access IAM User
resource "aws_iam_user" "sqs_access" {
  name = "kishax-${var.environment}-sqs-access"
  
  tags = {
    Name        = "kishax-${var.environment}-sqs-access"
    Description = "SQS access for Docker containers"
  }
}

# SQS Access Policy
resource "aws_iam_user_policy" "sqs_access" {
  name = "kishax-${var.environment}-sqs-access-policy"
  user = aws_iam_user.sqs_access.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl",
          "sqs:ChangeMessageVisibility"
        ]
        Resource = "arn:aws:sqs:*:*:kishax-${var.environment}-*"
      }
    ]
  })
}

# Access Key for SQS User
resource "aws_iam_access_key" "sqs_access" {
  user = aws_iam_user.sqs_access.name
}

# Store Access Key ID in SSM Parameter Store
resource "aws_ssm_parameter" "sqs_access_key_id" {
  name        = "/kishax/${var.environment}/sqs/access-key-id"
  description = "SQS Access Key ID for Docker containers"
  type        = "SecureString"
  value       = aws_iam_access_key.sqs_access.id

  tags = {
    Name = "kishax-${var.environment}-sqs-access-key-id"
  }
}

# Store Secret Access Key in SSM Parameter Store
resource "aws_ssm_parameter" "sqs_secret_access_key" {
  name        = "/kishax/${var.environment}/sqs/secret-access-key"
  description = "SQS Secret Access Key for Docker containers"
  type        = "SecureString"
  value       = aws_iam_access_key.sqs_access.secret

  tags = {
    Name = "kishax-${var.environment}-sqs-secret-access-key"
  }
}
