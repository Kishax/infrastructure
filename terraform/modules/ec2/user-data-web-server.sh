#!/bin/bash
# Web Server (i-c) User Data Script
# - Update Route53 record with current public IP
# - Install Docker and Docker Compose
# - Setup Web and Discord Bot environment

set -e

# Logging
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "========================================="
echo "Web Server (i-c) Initialization Started"
echo "========================================="

# Get instance metadata
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)

echo "Instance ID: $INSTANCE_ID"
echo "Public IP: $PUBLIC_IP"
echo "Region: $REGION"

# Update Route53 record for kishax.net
echo "Updating Route53 record for ${web_domain_name}..."
CHANGE_BATCH=$(cat <<EOF
{
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "${web_domain_name}",
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
sudo mkdir -p /opt/web
sudo chown -R ec2-user:ec2-user /opt/web

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
echo "Cloning Web application from GitHub..."
cd /tmp
git clone -b master https://github.com/Kishax/kishax-web.git web-repo
sudo cp -r web-repo/* /opt/web/
rm -rf web-repo
sudo chown -R ec2-user:ec2-user /opt/web

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
REDIS_WEB_PORT=$(get_param "/kishax/production/dynamic/redis_web_port")

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

# Build PostgreSQL connection string with URL encoding
PG_HOST=$(get_param "/kishax/production/shared/postgres_host")
PG_DB=$(get_param "/kishax/production/shared/postgres_database")
PG_USER=$(get_param "/kishax/production/shared/postgres_user")
PG_PASS=$(get_secret_param "/kishax/production/shared/postgres_password")

# Generate .env file
cat > /opt/web/.env <<EOF
# ===================================
# Web Server Configuration (i-c, EC2)
# ===================================

# Database Configuration (RDS PostgreSQL)
DATABASE_URL=postgresql://${PG_USER}:${PG_PASS}@${PG_HOST}:5432/${PG_DB}

# AWS SQS Configuration
AWS_REGION=$(get_param "/kishax/production/shared/aws_region")
MC_WEB_SQS_ACCESS_KEY_ID=$(get_param "/kishax/production/shared/sqs_access_key_id")
MC_WEB_SQS_SECRET_ACCESS_KEY=$(get_secret_param "/kishax/production/shared/sqs_secret_access_key")
TO_WEB_QUEUE_URL=$(get_param "/kishax/production/shared/to_web_queue_url")
TO_MC_QUEUE_URL=$(get_param "/kishax/production/shared/to_mc_queue_url")
TO_DISCORD_QUEUE_URL=$(get_param "/kishax/production/shared/to_discord_queue_url")

# Redis Configuration (i-b上のRedis #2)
REDIS_URL=redis://${API_PRIVATE_IP}:${REDIS_WEB_PORT}
REDIS_CONNECTION_TIMEOUT=$(get_param "/kishax/production/web/redis_connection_timeout")
REDIS_COMMAND_TIMEOUT=$(get_param "/kishax/production/web/redis_command_timeout")

# Queue Mode
QUEUE_MODE=$(get_param "/kishax/production/web/queue_mode")
SQS_WORKER_ENABLED=$(get_param "/kishax/production/web/sqs_worker_enabled")

# NextAuth Configuration
NEXTAUTH_URL=$(get_param "/kishax/production/web/nextauth_url")
NEXTAUTH_SECRET="$(get_secret_param "/kishax/production/web/nextauth_secret")"

# OAuth Providers
GOOGLE_CLIENT_ID=$(get_param "/kishax/production/web/google_client_id")
GOOGLE_CLIENT_SECRET=$(get_secret_param "/kishax/production/web/google_client_secret")
DISCORD_CLIENT_ID=$(get_param "/kishax/production/web/discord_client_id")
DISCORD_CLIENT_SECRET=$(get_secret_param "/kishax/production/web/discord_client_secret")
TWITTER_CLIENT_ID=$(get_param "/kishax/production/web/twitter_client_id")
TWITTER_CLIENT_SECRET=$(get_secret_param "/kishax/production/web/twitter_client_secret")

# Email Configuration (SMTP)
EMAIL_HOST=$(get_param "/kishax/production/web/email_host")
EMAIL_PORT=$(get_param "/kishax/production/web/email_port")
EMAIL_USER=$(get_param "/kishax/production/web/email_user")
EMAIL_PASS=$(get_secret_param "/kishax/production/web/email_pass")
EMAIL_FROM=$(get_param "/kishax/production/web/email_from")

# Application Configuration
NODE_ENV=$(get_param "/kishax/production/web/node_env")
PORT=$(get_param "/kishax/production/web/port")

# Logging Configuration
LOG_LEVEL=$(get_param "/kishax/production/web/log_level")

# Internal API Key (for server-to-server communication)
INTERNAL_API_KEY=$(get_secret_param "/kishax/production/web/internal_api_key")
EOF

sudo chmod 600 /opt/web/.env
sudo chown ec2-user:ec2-user /opt/web/.env

echo ".env file generated successfully from SSM Parameter Store"

# Download Docker image from S3
echo "Downloading Docker image from S3..."
aws s3 cp s3://kishax-production-docker-images/web/kishax-web-latest.tar.gz \
  /tmp/kishax-web-latest.tar.gz --region $REGION

# Load Docker image
echo "Loading Docker image..."
docker load < /tmp/kishax-web-latest.tar.gz

# Clean up
rm /tmp/kishax-web-latest.tar.gz

echo "Docker image loaded successfully"

# Create systemd service for Web application
cat > /etc/systemd/system/web.service <<'SERVICE'
[Unit]
Description=Web Application
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/web
ExecStart=/usr/local/lib/docker/cli-plugins/docker-compose up -d
ExecStop=/usr/local/lib/docker/cli-plugins/docker-compose down
User=ec2-user

[Install]
WantedBy=multi-user.target
SERVICE

echo "systemd service created at /etc/systemd/system/web.service"

# Enable and start Web service
echo "Enabling and starting Web service..."
systemctl daemon-reload
systemctl enable web.service
systemctl start web.service

# Check service status
echo "Web service status:"
systemctl status web.service --no-pager

echo "========================================="
echo "Web Server (i-c) Initialization Complete"
echo "========================================="
echo "Public IP: $PUBLIC_IP"
echo "Route53: ${web_domain_name} -> $PUBLIC_IP"
echo "Application deployed to: /opt/web"
echo "Service status: $(systemctl is-active web.service)"
