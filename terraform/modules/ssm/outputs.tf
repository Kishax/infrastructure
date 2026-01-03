# SSM Parameter Store Module - Outputs

# Output the parameter name prefix for use in user-data scripts
output "parameter_prefix" {
  description = "SSM parameter prefix path"
  value       = "/kishax/${var.environment}"
}

# Output dynamic parameter names that will be updated by EC2 instances
output "dynamic_api_server_private_ip_parameter" {
  description = "SSM parameter name for API server private IP (updated by i-b)"
  value       = aws_ssm_parameter.dynamic_api_server_private_ip.name
}

output "dynamic_redis_mc_port_parameter" {
  description = "SSM parameter name for Redis MC port"
  value       = aws_ssm_parameter.dynamic_redis_mc_port.name
}

output "dynamic_redis_web_port_parameter" {
  description = "SSM parameter name for Redis Web port"
  value       = aws_ssm_parameter.dynamic_redis_web_port.name
}
