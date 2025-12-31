# RDS Module - Outputs

output "postgres_endpoint" {
  description = "PostgreSQL RDS endpoint"
  value       = aws_db_instance.postgres.endpoint
  sensitive   = true
}

output "postgres_address" {
  description = "PostgreSQL RDS address"
  value       = aws_db_instance.postgres.address
}

output "postgres_port" {
  description = "PostgreSQL RDS port"
  value       = aws_db_instance.postgres.port
}

output "postgres_db_name" {
  description = "PostgreSQL database name"
  value       = aws_db_instance.postgres.db_name
}

output "mysql_endpoint" {
  description = "MySQL RDS endpoint"
  value       = aws_db_instance.mysql.endpoint
  sensitive   = true
}

output "mysql_address" {
  description = "MySQL RDS address"
  value       = aws_db_instance.mysql.address
}

output "mysql_port" {
  description = "MySQL RDS port"
  value       = aws_db_instance.mysql.port
}

output "mysql_db_name" {
  description = "MySQL database name"
  value       = aws_db_instance.mysql.db_name
}
