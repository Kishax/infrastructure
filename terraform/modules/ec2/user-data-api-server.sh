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

# Download .env file from S3
echo "Downloading .env file from S3..."
aws s3 cp s3://kishax-production-env-files/i-b/api/.env /opt/api/.env --region $REGION
sudo chmod 600 /opt/api/.env
sudo chown ec2-user:ec2-user /opt/api/.env

echo ".env file downloaded successfully"

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
