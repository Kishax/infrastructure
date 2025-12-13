# Security Groups Module - Main Configuration

# MC Server Security Group (i-a)
resource "aws_security_group" "mc_server" {
  name        = "kishax-${var.environment}-mc-server-sg"
  description = "Security group for Minecraft Server (i-a)"
  vpc_id      = var.vpc_id

  # Minecraft client connections
  ingress {
    description = "Minecraft client connections"
    from_port   = 25565
    to_port     = 25565
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH access (management)
  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # TODO: Restrict to specific IP
  }

  # Allow all outbound traffic
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "kishax-${var.environment}-mc-server-sg"
    Instance = "i-a"
  }
}

# API Server Security Group (i-b)
resource "aws_security_group" "api_server" {
  name        = "kishax-${var.environment}-api-server-sg"
  description = "Security group for API Server (i-b)"
  vpc_id      = var.vpc_id

  # HTTP from i-a and i-c
  ingress {
    description     = "HTTP from MC Server (i-a)"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.mc_server.id]
  }

  ingress {
    description     = "HTTP from Web Server (i-c)"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.web_server.id]
  }

  # Redis from i-a and i-c
  ingress {
    description     = "Redis from MC Server (i-a)"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.mc_server.id]
  }

  ingress {
    description     = "Redis from Web Server (i-c)"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.web_server.id]
  }

  # SSH access (management)
  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # TODO: Restrict to specific IP
  }

  # Allow all outbound traffic
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name     = "kishax-${var.environment}-api-server-sg"
    Instance = "i-b"
  }
}

# Web Server Security Group (i-c)
resource "aws_security_group" "web_server" {
  name        = "kishax-${var.environment}-web-server-sg"
  description = "Security group for Web Server (i-c)"
  vpc_id      = var.vpc_id

  # HTTP from anywhere (via CloudFront)
  ingress {
    description = "HTTP from CloudFront"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # TODO: Restrict to CloudFront IP ranges
  }

  # HTTPS from anywhere (via CloudFront)
  ingress {
    description = "HTTPS from CloudFront"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # TODO: Restrict to CloudFront IP ranges
  }

  # SSH access (management)
  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # TODO: Restrict to specific IP
  }

  # Allow all outbound traffic
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name     = "kishax-${var.environment}-web-server-sg"
    Instance = "i-c"
  }
}

# Jump Server Security Group (i-d)
resource "aws_security_group" "jump_server" {
  name        = "kishax-${var.environment}-jump-server-sg"
  description = "Security group for Jump Server (i-d)"
  vpc_id      = var.vpc_id

  # SSH access via SSM Session Manager (no direct inbound needed)
  # SSM Session Manager doesn't require SSH port open

  # Allow all outbound traffic
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name     = "kishax-${var.environment}-jump-server-sg"
    Instance = "i-d"
  }
}

# RDS Security Group
resource "aws_security_group" "rds" {
  name        = "kishax-${var.environment}-rds-sg"
  description = "Security group for RDS instances"
  vpc_id      = var.vpc_id

  # PostgreSQL from i-b and i-c
  ingress {
    description     = "PostgreSQL from API Server (i-b)"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.api_server.id]
  }

  ingress {
    description     = "PostgreSQL from Web Server (i-c)"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.web_server.id]
  }

  ingress {
    description     = "PostgreSQL from Jump Server (i-d)"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.jump_server.id]
  }

  # MySQL from i-a
  ingress {
    description     = "MySQL from MC Server (i-a)"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.mc_server.id]
  }

  ingress {
    description     = "MySQL from Jump Server (i-d)"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.jump_server.id]
  }

  # Allow all outbound traffic
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "kishax-${var.environment}-rds-sg"
  }
}
