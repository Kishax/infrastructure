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
          "ssm:GetParametersByPath"
        ]
        Resource = "arn:aws:ssm:*:*:parameter/kishax/*"
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
