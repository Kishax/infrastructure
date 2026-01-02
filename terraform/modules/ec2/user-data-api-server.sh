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
yum install -y docker
systemctl start docker
systemctl enable docker

# Install Docker Compose
echo "Installing Docker Compose..."
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install Redis
echo "Installing Redis..."
yum install -y redis

# Configure Redis for network access
echo "Configuring Redis..."
sed -i 's/^bind 127.0.0.1/bind 0.0.0.0/' /etc/redis.conf
sed -i 's/^protected-mode yes/protected-mode no/' /etc/redis.conf

# Set Redis password (should be stored in SSM and retrieved)
# For now, using a placeholder
# REDIS_PASSWORD=$(aws ssm get-parameter --name /kishax/redis/password --with-decryption --query 'Parameter.Value' --output text --region $REGION)
# echo "requirepass $REDIS_PASSWORD" >> /etc/redis.conf

# Start Redis
systemctl start redis
systemctl enable redis

echo "Redis status:"
systemctl status redis --no-pager

# Create api user
echo "Creating api user..."
useradd -m -s /bin/bash api
usermod -aG docker api

# Create directories
echo "Creating application directories..."
mkdir -p /opt/api
chown -R api:api /opt/api

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
cp -r api-repo/* /opt/api/
rm -rf api-repo
chown -R api:api /opt/api

# Download .env file from S3
echo "Downloading .env file from S3..."
aws s3 cp s3://kishax-production-env-files/i-b/api/.env /opt/api/.env --region $REGION
chmod 600 /opt/api/.env
chown api:api /opt/api/.env

echo ".env file downloaded successfully"

# Create systemd service for API server (optional)
cat > /etc/systemd/system/api.service <<'SERVICE'
[Unit]
Description=API Server
After=docker.service redis.service
Requires=docker.service redis.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/api
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
User=api

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
echo "Redis endpoint: $PRIVATE_IP:6379"
echo "Application deployed to: /opt/api"
echo "Service status: $(systemctl is-active api.service)"
