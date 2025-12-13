# RDS Module - Main Configuration

# RDS Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "kishax-${var.environment}-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "kishax-${var.environment}-db-subnet-group"
  }
}

# PostgreSQL RDS Instance
resource "aws_db_instance" "postgres" {
  identifier = "kishax-${var.environment}-postgres"

  # Engine
  engine         = "postgres"
  engine_version = "16.6"  # 利用可能な最新安定版

  # Instance
  instance_class        = var.postgres_instance_class
  allocated_storage     = var.postgres_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  # Database
  db_name  = var.postgres_db_name
  username = var.postgres_username
  password = var.postgres_password
  port     = 5432

  # Network
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.rds_security_group_id]
  publicly_accessible    = false

  # Backup
  backup_retention_period = 3  # コスト削減: 3日間
  backup_window          = "03:00-04:00"
  maintenance_window     = "mon:04:00-mon:05:00"
  skip_final_snapshot    = false
  final_snapshot_identifier = "kishax-${var.environment}-postgres-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  # High Availability
  multi_az = false  # コスト削減: シングルAZ

  # Monitoring
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  monitoring_interval             = 60
  monitoring_role_arn             = aws_iam_role.rds_monitoring.arn

  # Performance
  performance_insights_enabled = false  # コスト削減

  # Deletion Protection
  deletion_protection = false  # 開発中はfalse、本番はtrue

  tags = {
    Name = "kishax-${var.environment}-postgres"
    Type = "PostgreSQL"
  }

  lifecycle {
    ignore_changes = [
      final_snapshot_identifier
    ]
  }
}

# MySQL RDS Instance (Minecraft Server用)
resource "aws_db_instance" "mysql" {
  identifier = "kishax-${var.environment}-mysql"

  # Engine
  engine         = "mysql"
  engine_version = "8.0.40"  # 利用可能な最新安定版

  # Instance
  instance_class        = var.mysql_instance_class
  allocated_storage     = var.mysql_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  # Database
  db_name  = var.mysql_db_name
  username = var.mysql_username
  password = var.mysql_password
  port     = 3306

  # Network
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.rds_security_group_id]
  publicly_accessible    = false

  # Backup
  backup_retention_period = 3  # コスト削減: 3日間
  backup_window          = "03:00-04:00"
  maintenance_window     = "mon:04:00-mon:05:00"
  skip_final_snapshot    = false
  final_snapshot_identifier = "kishax-${var.environment}-mysql-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  # High Availability
  multi_az = false  # コスト削減: シングルAZ

  # Monitoring
  enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"]
  monitoring_interval             = 60
  monitoring_role_arn             = aws_iam_role.rds_monitoring.arn

  # Performance
  performance_insights_enabled = false  # コスト削減

  # Deletion Protection
  deletion_protection = false  # 開発中はfalse、本番はtrue

  # MySQL Specific
  parameter_group_name = aws_db_parameter_group.mysql.name

  tags = {
    Name = "kishax-${var.environment}-mysql"
    Type = "MySQL"
  }

  lifecycle {
    ignore_changes = [
      final_snapshot_identifier
    ]
  }
}

# MySQL Parameter Group (UTF-8 設定)
resource "aws_db_parameter_group" "mysql" {
  name   = "kishax-${var.environment}-mysql-params"
  family = "mysql8.0"

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  parameter {
    name  = "collation_server"
    value = "utf8mb4_unicode_ci"
  }

  parameter {
    name  = "max_connections"
    value = "100"
  }

  tags = {
    Name = "kishax-${var.environment}-mysql-params"
  }
}

# RDS Enhanced Monitoring IAM Role
resource "aws_iam_role" "rds_monitoring" {
  name = "kishax-${var.environment}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "kishax-${var.environment}-rds-monitoring-role"
  }
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}
