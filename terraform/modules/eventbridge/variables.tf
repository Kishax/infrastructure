# EventBridge Module - Variables

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "lambda_function_arn" {
  description = "Lambda function ARN for EC2 scheduler"
  type        = string
}

variable "mc_server_instance_id" {
  description = "MC Server (i-a) instance ID"
  type        = string
}

variable "api_server_instance_id" {
  description = "API Server (i-b) instance ID"
  type        = string
}

variable "web_server_instance_id" {
  description = "Web Server (i-c) instance ID"
  type        = string
}
