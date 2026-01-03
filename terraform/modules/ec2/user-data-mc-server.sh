#!/bin/bash
# MC Server (i-a) User Data Script
# - Update Route53 record with current public IP
# - Install Docker and Docker Compose
# - Setup Minecraft server environment

set -e

# Logging
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "========================================="
echo "MC Server (i-a) Initialization Started"
echo "========================================="

# Get instance metadata
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)

echo "Instance ID: $INSTANCE_ID"
echo "Public IP: $PUBLIC_IP"
echo "Region: $REGION"

# Update Route53 record
echo "Updating Route53 record for ${mc_domain_name}..."
CHANGE_BATCH=$(cat <<EOF
{
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "${mc_domain_name}",
        "Type": "A",
        "TTL": 60,
        "ResourceRecords": [
          {
            "Value": "$PUBLIC_IP"
          }
        ]
      }
    }
  ]
}
EOF
)

aws route53 change-resource-record-sets \
    --hosted-zone-id ${route53_zone_id} \
    --change-batch "$CHANGE_BATCH" \
    --region $REGION

echo "Route53 record updated successfully"

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
sudo mkdir -p /opt/mc/data
sudo mkdir -p /opt/mc/images
sudo chown -R ec2-user:ec2-user /opt/mc

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
echo "Cloning MC application from GitHub..."
cd /tmp
git clone -b master https://github.com/Kishax/kishax.git mc-repo
sudo cp -r mc-repo/* /opt/mc/
rm -rf mc-repo
sudo chown -R ec2-user:ec2-user /opt/mc

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

# Get dynamic API server private IP
API_PRIVATE_IP=$(get_param "/kishax/production/dynamic/api_server_private_ip")
REDIS_MC_PORT=$(get_param "/kishax/production/dynamic/redis_mc_port")

# Wait for API server to register its IP (max 60 seconds)
COUNTER=0
while [ -z "$API_PRIVATE_IP" ] || [ "$API_PRIVATE_IP" = "0.0.0.0" ]; do
  if [ $COUNTER -ge 12 ]; then
    echo "Warning: API server private IP not available after 60 seconds, using placeholder"
    API_PRIVATE_IP="0.0.0.0"
    break
  fi
  echo "Waiting for API server to register its private IP... ($COUNTER/12)"
  sleep 5
  API_PRIVATE_IP=$(get_param "/kishax/production/dynamic/api_server_private_ip")
  COUNTER=$((COUNTER + 1))
done

echo "API Server Private IP: $API_PRIVATE_IP"

# Generate .env file
cat > /opt/mc/.env <<EOF
# ===================================
# MC Server Configuration (i-a, EC2)
# ===================================

# Overall Memory Configuration
OVERALL_MEMORY=$(get_param "/kishax/production/mc/overall_memory")

# MySQL Configuration (RDS MySQL)
MYSQL_HOST=$(get_param "/kishax/production/shared/mysql_host")
MYSQL_DATABASE=$(get_param "/kishax/production/shared/mysql_database")
MYSQL_USER=$(get_param "/kishax/production/shared/mysql_user")
MYSQL_PASSWORD='$(get_secret_param "/kishax/production/shared/mysql_password")'

# Seed Control (production: skip seeds, development: load seeds)
SEED_ENV=$(get_param "/kishax/production/mc/seed_env")

# Auth API Configuration (i-b)
AUTH_API_URL=http://${API_PRIVATE_IP}:8080
AUTH_API_KEY=$(get_secret_param "/kishax/production/shared/auth_api_key")
MC_CONFIRM_BASE_URL=$(get_param "/kishax/production/mc/mc_confirm_base_url")

# AWS SQS Configuration
AWS_REGION=$(get_param "/kishax/production/shared/aws_region")
MC_WEB_SQS_ACCESS_KEY_ID=$(get_param "/kishax/production/shared/sqs_access_key_id")
MC_WEB_SQS_SECRET_ACCESS_KEY=$(get_secret_param "/kishax/production/shared/sqs_secret_access_key")
TO_WEB_QUEUE_URL=$(get_param "/kishax/production/shared/to_web_queue_url")
TO_MC_QUEUE_URL=$(get_param "/kishax/production/shared/to_mc_queue_url")
TO_DISCORD_QUEUE_URL=$(get_param "/kishax/production/shared/to_discord_queue_url")

# Redis Configuration (i-b host Redis #1)
REDIS_URL=redis://${API_PRIVATE_IP}:${REDIS_MC_PORT}
REDIS_CONNECTION_TIMEOUT=$(get_param "/kishax/production/mc/redis_connection_timeout")
REDIS_COMMAND_TIMEOUT=$(get_param "/kishax/production/mc/redis_command_timeout")

# Queue Configuration
QUEUE_MODE=$(get_param "/kishax/production/mc/queue_mode")
SQS_WORKER_ENABLED=$(get_param "/kishax/production/mc/sqs_worker_enabled")
SQS_WORKER_POLLING_INTERVAL_SECONDS=$(get_param "/kishax/production/mc/sqs_worker_polling_interval_seconds")
SQS_WORKER_MAX_MESSAGES=$(get_param "/kishax/production/mc/sqs_worker_max_messages")
SQS_WORKER_WAIT_TIME_SECONDS=$(get_param "/kishax/production/mc/sqs_worker_wait_time_seconds")
SQS_WORKER_VISIBILITY_TIMEOUT_SECONDS=$(get_param "/kishax/production/mc/sqs_worker_visibility_timeout_seconds")

# Logging Configuration
LOG_LEVEL=$(get_param "/kishax/production/mc/log_level")

# Kishax APIをDocker環境でビルドするときのGithubのブランチ名
KISHAX_API_BRANCH=$(get_param "/kishax/production/mc/kishax_api_branch")
EOF

sudo chmod 600 /opt/mc/.env
sudo chown ec2-user:ec2-user /opt/mc/.env

echo ".env file generated successfully from SSM Parameter Store"

# Download Docker image from S3
echo "Downloading Docker image from S3..."
aws s3 cp s3://kishax-production-docker-images/mc/kishax-mc-latest.tar.gz \
  /tmp/kishax-mc-latest.tar.gz --region $REGION

# Load Docker image
echo "Loading Docker image..."
docker load < /tmp/kishax-mc-latest.tar.gz

# Clean up
rm /tmp/kishax-mc-latest.tar.gz

echo "Docker image loaded successfully"

# Create systemd service for Minecraft server
cat > /etc/systemd/system/minecraft.service <<'SERVICE'
[Unit]
Description=Minecraft Server
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/mc
ExecStart=/usr/local/lib/docker/cli-plugins/docker-compose up -d
ExecStop=/usr/local/lib/docker/cli-plugins/docker-compose down
User=ec2-user

[Install]
WantedBy=multi-user.target
SERVICE

echo "systemd service created at /etc/systemd/system/minecraft.service"

# Enable and start Minecraft service
echo "Enabling and starting Minecraft service..."
systemctl daemon-reload
systemctl enable minecraft.service
systemctl start minecraft.service

# Check service status
echo "Minecraft service status:"
systemctl status minecraft.service --no-pager

echo "========================================="
echo "MC Server (i-a) Initialization Complete"
echo "========================================="
echo "Public IP: $PUBLIC_IP"
echo "Route53: ${mc_domain_name} -> $PUBLIC_IP"
echo "Application deployed to: /opt/mc"
echo "Service status: $(systemctl is-active minecraft.service)"
