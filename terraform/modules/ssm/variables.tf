# SSM Parameter Store Module - Variables

variable "environment" {
  description = "Environment name (production, staging, etc.)"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all SSM parameters"
  type        = map(string)
  default     = {}
}

# ===================================
# Shared Parameters
# ===================================

variable "aws_region" {
  description = "AWS Region"
  type        = string
}

variable "sqs_access_key_id" {
  description = "SQS Access Key ID"
  type        = string
}

variable "sqs_secret_access_key" {
  description = "SQS Secret Access Key"
  type        = string
  sensitive   = true
}

variable "to_web_queue_url" {
  description = "SQS Queue URL for to-web queue"
  type        = string
}

variable "to_mc_queue_url" {
  description = "SQS Queue URL for to-mc queue"
  type        = string
}

variable "to_discord_queue_url" {
  description = "SQS Queue URL for to-discord queue"
  type        = string
}

variable "mysql_host" {
  description = "MySQL RDS endpoint"
  type        = string
}

variable "mysql_database" {
  description = "MySQL database name"
  type        = string
}

variable "mysql_user" {
  description = "MySQL username"
  type        = string
}

variable "mysql_password" {
  description = "MySQL password"
  type        = string
  sensitive   = true
}

variable "postgres_host" {
  description = "PostgreSQL RDS endpoint"
  type        = string
}

variable "postgres_database" {
  description = "PostgreSQL database name"
  type        = string
}

variable "postgres_user" {
  description = "PostgreSQL username"
  type        = string
}

variable "postgres_password" {
  description = "PostgreSQL password"
  type        = string
  sensitive   = true
}

variable "auth_api_key" {
  description = "Auth API Key"
  type        = string
  sensitive   = true
}

# ===================================
# MC Server (i-a) Parameters
# ===================================

variable "mc_overall_memory" {
  description = "MC Server overall memory allocation"
  type        = string
  default     = "8.0"
}

variable "mc_seed_env" {
  description = "MC Server seed environment (production/development)"
  type        = string
  default     = "production"
}

variable "mc_confirm_base_url" {
  description = "MC Confirm Base URL"
  type        = string
}

variable "mc_redis_connection_timeout" {
  description = "Redis connection timeout for MC"
  type        = string
  default     = "5000"
}

variable "mc_redis_command_timeout" {
  description = "Redis command timeout for MC"
  type        = string
  default     = "3000"
}

variable "mc_queue_mode" {
  description = "Queue mode for MC"
  type        = string
  default     = "MC"
}

variable "mc_sqs_worker_enabled" {
  description = "Enable SQS worker for MC"
  type        = string
  default     = "true"
}

variable "mc_sqs_worker_polling_interval_seconds" {
  description = "SQS worker polling interval for MC"
  type        = string
  default     = "5"
}

variable "mc_sqs_worker_max_messages" {
  description = "SQS worker max messages for MC"
  type        = string
  default     = "10"
}

variable "mc_sqs_worker_wait_time_seconds" {
  description = "SQS worker wait time for MC"
  type        = string
  default     = "20"
}

variable "mc_sqs_worker_visibility_timeout_seconds" {
  description = "SQS worker visibility timeout for MC"
  type        = string
  default     = "30"
}

variable "mc_log_level" {
  description = "Log level for MC"
  type        = string
  default     = "INFO"
}

variable "mc_kishax_api_branch" {
  description = "Kishax API branch for MC"
  type        = string
  default     = "master"
}

# ===================================
# Web Server (i-c) Parameters
# ===================================

variable "web_queue_mode" {
  description = "Queue mode for Web"
  type        = string
  default     = "WEB"
}

variable "web_sqs_worker_enabled" {
  description = "Enable SQS worker for Web"
  type        = string
  default     = "false"
}

variable "web_nextauth_url" {
  description = "NextAuth URL"
  type        = string
}

variable "web_nextauth_secret" {
  description = "NextAuth secret"
  type        = string
  sensitive   = true
}

variable "web_google_client_id" {
  description = "Google OAuth Client ID"
  type        = string
}

variable "web_google_client_secret" {
  description = "Google OAuth Client Secret"
  type        = string
  sensitive   = true
}

variable "web_discord_client_id" {
  description = "Discord OAuth Client ID"
  type        = string
}

variable "web_discord_client_secret" {
  description = "Discord OAuth Client Secret"
  type        = string
  sensitive   = true
}

variable "web_twitter_client_id" {
  description = "Twitter OAuth Client ID"
  type        = string
}

variable "web_twitter_client_secret" {
  description = "Twitter OAuth Client Secret"
  type        = string
  sensitive   = true
}

variable "web_email_host" {
  description = "Email SMTP host"
  type        = string
}

variable "web_email_port" {
  description = "Email SMTP port"
  type        = string
  default     = "587"
}

variable "web_email_user" {
  description = "Email SMTP user"
  type        = string
}

variable "web_email_pass" {
  description = "Email SMTP password"
  type        = string
  sensitive   = true
}

variable "web_email_from" {
  description = "Email from address"
  type        = string
}

variable "web_node_env" {
  description = "Node environment"
  type        = string
  default     = "production"
}

variable "web_port" {
  description = "Web server port"
  type        = string
  default     = "80"
}

variable "web_log_level" {
  description = "Log level for Web"
  type        = string
  default     = "info"
}

variable "web_internal_api_key" {
  description = "Internal API key for Web"
  type        = string
  sensitive   = true
}

variable "web_redis_connection_timeout" {
  description = "Redis connection timeout for Web"
  type        = string
  default     = "5000"
}

variable "web_redis_command_timeout" {
  description = "Redis command timeout for Web"
  type        = string
  default     = "3000"
}

# ===================================
# API Server (i-b) Parameters
# ===================================

variable "api_redis_url_discord" {
  description = "Redis URL for Discord bot (Docker network)"
  type        = string
  default     = "redis://redis-mc:6379"
}

variable "api_auth_api_enabled" {
  description = "Enable Auth API"
  type        = string
  default     = "true"
}

variable "api_auth_api_port" {
  description = "Auth API port"
  type        = string
  default     = "8080"
}

variable "api_discord_token" {
  description = "Discord bot token"
  type        = string
  sensitive   = true
}

variable "api_discord_channel_id" {
  description = "Discord channel ID"
  type        = string
}

variable "api_discord_chat_channel_id" {
  description = "Discord chat channel ID"
  type        = string
}

variable "api_discord_admin_channel_id" {
  description = "Discord admin channel ID"
  type        = string
}

variable "api_discord_rule_channel_id" {
  description = "Discord rule channel ID"
  type        = string
}

variable "api_discord_rule_message_id" {
  description = "Discord rule message ID"
  type        = string
}

variable "api_discord_guild_id" {
  description = "Discord guild ID"
  type        = string
}

variable "api_discord_presence_activity" {
  description = "Discord presence activity"
  type        = string
  default     = "mc.kishax.net"
}

variable "api_be_default_emoji_name" {
  description = "Default emoji name for BE"
  type        = string
  default     = "steve"
}

variable "api_aws_sqs_max_messages" {
  description = "AWS SQS max messages"
  type        = string
  default     = "10"
}

variable "api_aws_sqs_wait_time_seconds" {
  description = "AWS SQS wait time seconds"
  type        = string
  default     = "20"
}

variable "api_sqs_worker_polling_interval" {
  description = "SQS worker polling interval"
  type        = string
  default     = "5"
}

variable "api_sqs_worker_max_messages" {
  description = "SQS worker max messages"
  type        = string
  default     = "10"
}

variable "api_sqs_worker_wait_time" {
  description = "SQS worker wait time"
  type        = string
  default     = "20"
}

variable "api_sqs_worker_visibility_timeout" {
  description = "SQS worker visibility timeout"
  type        = string
  default     = "300"
}

variable "api_shutdown_grace_period" {
  description = "Shutdown grace period"
  type        = string
  default     = "10"
}

variable "api_log_level" {
  description = "Log level for API"
  type        = string
  default     = "INFO"
}

# ===================================
# Terraria Server (i-e) Parameters
# ===================================

variable "terraria_s3_bucket" {
  description = "S3 bucket for Terraria backups"
  type        = string
}

variable "terraria_s3_download_enabled" {
  description = "Enable S3 download for Terraria"
  type        = string
  default     = "true"
}

variable "terraria_server_password" {
  description = "Terraria server password"
  type        = string
  sensitive   = true
}

variable "terraria_server_port" {
  description = "Terraria server port"
  type        = string
  default     = "7777"
}

variable "terraria_max_slots" {
  description = "Terraria max slots"
  type        = string
  default     = "8"
}

variable "terraria_server_name" {
  description = "Terraria server name"
  type        = string
  default     = "Kishax Terraria Server"
}

variable "terraria_discord_bot_token" {
  description = "Terraria Discord bot token"
  type        = string
  sensitive   = true
}

variable "terraria_discord_channel_id" {
  description = "Terraria Discord channel ID"
  type        = string
}

variable "terraria_rest_api_enabled" {
  description = "Enable Terraria REST API"
  type        = string
  default     = "true"
}

variable "terraria_rest_api_port" {
  description = "Terraria REST API port"
  type        = string
  default     = "7878"
}

variable "terraria_rest_api_token" {
  description = "Terraria REST API token"
  type        = string
  sensitive   = true
}

variable "terraria_rest_api_username" {
  description = "Terraria REST API username"
  type        = string
  default     = "admin"
}

variable "terraria_rest_api_usergroup" {
  description = "Terraria REST API user group"
  type        = string
  default     = "superadmin"
}

variable "terraria_discord_presence_activity" {
  description = "Terraria Discord presence activity"
  type        = string
  default     = "tera.kishax.net"
}
