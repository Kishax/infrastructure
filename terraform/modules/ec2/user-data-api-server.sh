#!/bin/bash
# API Server (i-b) User Data Script
# - Install Docker and Docker Compose
# - Install and configure Redis
# - Setup API server environment

set -e

# Logging
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "========================================="
echo "API Server (i-b) Initialization Started"
echo "========================================="

# Get instance metadata
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)

echo "Instance ID: $INSTANCE_ID"
echo "Private IP: $PRIVATE_IP"
echo "Region: $REGION"

# System update
echo "Updating system packages..."
yum update -y

# Install Docker
echo "Installing Docker..."
sudo yum install -y docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ec2-user

# Install Docker Compose v2
echo "Installing Docker Compose v2..."
sudo mkdir -p /usr/local/lib/docker/cli-plugins
sudo curl -L "https://github.com/docker/compose/releases/download/v2.32.1/docker-compose-$(uname -s)-$(uname -m)" \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# Create directories
echo "Creating application directories..."
sudo mkdir -p /opt/api
sudo chown -R ec2-user:ec2-user /opt/api

# Install AWS CLI (if not already installed)
if ! command -v aws &> /dev/null; then
    echo "Installing AWS CLI..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    ./aws/install
    rm -rf awscliv2.zip aws
fi

# Install Git
echo "Installing Git..."
yum install -y git

# Clone application repository
echo "Cloning API application from GitHub..."
cd /tmp
git clone -b master https://github.com/Kishax/kishax-api.git api-repo
sudo cp -r api-repo/* /opt/api/
rm -rf api-repo
sudo chown -R ec2-user:ec2-user /opt/api

# Update SSM Parameter with Private IP for dynamic discovery by other instances
echo "Updating SSM parameter with this instance's private IP..."
aws ssm put-parameter \
  --region $REGION \
  --name "/kishax/production/dynamic/api_server_private_ip" \
  --value "$PRIVATE_IP" \
  --type String \
  --overwrite

echo "SSM parameter updated: /kishax/production/dynamic/api_server_private_ip = $PRIVATE_IP"

# Generate .env file from SSM Parameter Store
echo "Generating .env file from SSM Parameter Store..."

# Function to get SSM parameter
get_param() {
  aws ssm get-parameter --region $REGION --name "$1" --query 'Parameter.Value' --output text 2>/dev/null || echo ""
}

# Function to get SSM parameter with decryption (for SecureString)
get_secret_param() {
  aws ssm get-parameter --region $REGION --name "$1" --with-decryption --query 'Parameter.Value' --output text 2>/dev/null || echo ""
}

# Fetch all SSM parameters as variables
echo "Fetching SSM parameters..."

# Shared parameters
POSTGRES_HOST=$(get_param "/kishax/production/shared/postgres_host")
POSTGRES_DATABASE=$(get_param "/kishax/production/shared/postgres_database")
POSTGRES_USER=$(get_param "/kishax/production/shared/postgres_user")
PG_PASS_RAW=$(get_secret_param "/kishax/production/shared/postgres_password")
PG_PASS_ENCODED=$(echo "${PG_PASS_RAW}" | sed 's/#/%23/g; s/\$/%24/g')

AWS_REGION_PARAM=$(get_param "/kishax/production/shared/aws_region")
SQS_ACCESS_KEY_ID=$(get_param "/kishax/production/shared/sqs_access_key_id")
SQS_SECRET_ACCESS_KEY=$(get_secret_param "/kishax/production/shared/sqs_secret_access_key")
TO_WEB_QUEUE_URL=$(get_param "/kishax/production/shared/to_web_queue_url")
TO_MC_QUEUE_URL=$(get_param "/kishax/production/shared/to_mc_queue_url")
TO_DISCORD_QUEUE_URL=$(get_param "/kishax/production/shared/to_discord_queue_url")
AUTH_API_KEY=$(get_secret_param "/kishax/production/shared/auth_api_key")

# API Server parameters
REDIS_URL_DISCORD=$(get_param "/kishax/production/api/redis_url_discord")
AUTH_API_ENABLED=$(get_param "/kishax/production/api/auth_api_enabled")
AUTH_API_PORT=$(get_param "/kishax/production/api/auth_api_port")
DISCORD_TOKEN=$(get_secret_param "/kishax/production/api/discord_token")
DISCORD_CHANNEL_ID=$(get_param "/kishax/production/api/discord_channel_id")
DISCORD_CHAT_CHANNEL_ID=$(get_param "/kishax/production/api/discord_chat_channel_id")
DISCORD_ADMIN_CHANNEL_ID=$(get_param "/kishax/production/api/discord_admin_channel_id")
DISCORD_RULE_CHANNEL_ID=$(get_param "/kishax/production/api/discord_rule_channel_id")
DISCORD_RULE_MESSAGE_ID=$(get_param "/kishax/production/api/discord_rule_message_id")
DISCORD_GUILD_ID=$(get_param "/kishax/production/api/discord_guild_id")
DISCORD_PRESENCE_ACTIVITY=$(get_param "/kishax/production/api/discord_presence_activity")
BE_DEFAULT_EMOJI_NAME=$(get_param "/kishax/production/api/be_default_emoji_name")
AWS_SQS_MAX_MESSAGES=$(get_param "/kishax/production/api/aws_sqs_max_messages")
AWS_SQS_WAIT_TIME_SECONDS=$(get_param "/kishax/production/api/aws_sqs_wait_time_seconds")
SQS_WORKER_POLLING_INTERVAL=$(get_param "/kishax/production/api/sqs_worker_polling_interval")
SQS_WORKER_MAX_MESSAGES=$(get_param "/kishax/production/api/sqs_worker_max_messages")
SQS_WORKER_WAIT_TIME=$(get_param "/kishax/production/api/sqs_worker_wait_time")
SQS_WORKER_VISIBILITY_TIMEOUT=$(get_param "/kishax/production/api/sqs_worker_visibility_timeout")
SHUTDOWN_GRACE_PERIOD=$(get_param "/kishax/production/api/shutdown_grace_period")
LOG_LEVEL=$(get_param "/kishax/production/api/log_level")

echo "SSM parameters fetched successfully"

# Generate .env file
cat > /opt/api/.env <<EOF
# ===================================
# API Server Configuration (i-b, EC2)
# ===================================

# Database Configuration (RDS PostgreSQL)
DATABASE_URL="jdbc:postgresql://${POSTGRES_HOST}/${POSTGRES_DATABASE}?user=${POSTGRES_USER}&password=${PG_PASS_ENCODED}"

# AWS SQS Configuration
AWS_REGION=${AWS_REGION_PARAM}
MC_WEB_SQS_ACCESS_KEY_ID="${SQS_ACCESS_KEY_ID}"
MC_WEB_SQS_SECRET_ACCESS_KEY=${SQS_SECRET_ACCESS_KEY}
TO_WEB_QUEUE_URL=${TO_WEB_QUEUE_URL}
TO_MC_QUEUE_URL=${TO_MC_QUEUE_URL}
TO_DISCORD_QUEUE_URL=${TO_DISCORD_QUEUE_URL}

# Redis Configuration for Discord Bot (Docker network内)
REDIS_URL_DISCORD=${REDIS_URL_DISCORD}

# Authentication API Configuration
AUTH_API_ENABLED=${AUTH_API_ENABLED}
AUTH_API_PORT=${AUTH_API_PORT}
AUTH_API_KEY=${AUTH_API_KEY}

# Discord Bot Configuration
DISCORD_TOKEN=${DISCORD_TOKEN}
DISCORD_CHANNEL_ID=${DISCORD_CHANNEL_ID}
DISCORD_CHAT_CHANNEL_ID=${DISCORD_CHAT_CHANNEL_ID}
DISCORD_ADMIN_CHANNEL_ID=${DISCORD_ADMIN_CHANNEL_ID}
DISCORD_RULE_CHANNEL_ID=${DISCORD_RULE_CHANNEL_ID}
DISCORD_RULE_MESSAGE_ID=${DISCORD_RULE_MESSAGE_ID}
DISCORD_GUILD_ID=${DISCORD_GUILD_ID}
DISCORD_PRESENCE_ACTIVITY=${DISCORD_PRESENCE_ACTIVITY}
BE_DEFAULT_EMOJI_NAME=${BE_DEFAULT_EMOJI_NAME}

# SQS Configuration for Discord
AWS_SQS_MAX_MESSAGES=${AWS_SQS_MAX_MESSAGES}
AWS_SQS_WAIT_TIME_SECONDS=${AWS_SQS_WAIT_TIME_SECONDS}
SQS_WORKER_POLLING_INTERVAL=${SQS_WORKER_POLLING_INTERVAL}
SQS_WORKER_MAX_MESSAGES=${SQS_WORKER_MAX_MESSAGES}
SQS_WORKER_WAIT_TIME=${SQS_WORKER_WAIT_TIME}
SQS_WORKER_VISIBILITY_TIMEOUT=${SQS_WORKER_VISIBILITY_TIMEOUT}

# Application Configuration
SHUTDOWN_GRACE_PERIOD=${SHUTDOWN_GRACE_PERIOD}

# Logging Configuration
LOG_LEVEL=${LOG_LEVEL}
EOF

sudo chmod 600 /opt/api/.env
sudo chown ec2-user:ec2-user /opt/api/.env

echo ".env file generated successfully from SSM Parameter Store"

# Download Docker images from S3
echo "Downloading Docker images from S3..."
aws s3 cp s3://kishax-production-docker-images/api/kishax-api-mc-auth-latest.tar.gz \
  /tmp/kishax-api-mc-auth-latest.tar.gz --region $REGION
aws s3 cp s3://kishax-production-docker-images/api/kishax-api-discord-bot-latest.tar.gz \
  /tmp/kishax-api-discord-bot-latest.tar.gz --region $REGION
aws s3 cp s3://kishax-production-docker-images/api/kishax-api-sqs-redis-bridge-web-latest.tar.gz \
  /tmp/kishax-api-sqs-redis-bridge-web-latest.tar.gz --region $REGION

# Load Docker images
echo "Loading Docker images..."
docker load < /tmp/kishax-api-mc-auth-latest.tar.gz
docker load < /tmp/kishax-api-discord-bot-latest.tar.gz
docker load < /tmp/kishax-api-sqs-redis-bridge-web-latest.tar.gz

# Clean up
rm /tmp/*.tar.gz

echo "Docker images loaded successfully"

# Create systemd service for API server
cat > /etc/systemd/system/api.service <<'SERVICE'
[Unit]
Description=API Server
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/api
ExecStart=/usr/local/lib/docker/cli-plugins/docker-compose up -d
ExecStop=/usr/local/lib/docker/cli-plugins/docker-compose down
User=ec2-user

[Install]
WantedBy=multi-user.target
SERVICE

echo "systemd service created at /etc/systemd/system/api.service"

# Enable and start API service
echo "Enabling and starting API service..."
systemctl daemon-reload
systemctl enable api.service
systemctl start api.service

# Check service status
echo "API service status:"
systemctl status api.service --no-pager

echo "========================================="
echo "API Server (i-b) Initialization Complete"
echo "========================================="
echo "Application deployed to: /opt/api"
echo "Service status: $(systemctl is-active api.service)"
