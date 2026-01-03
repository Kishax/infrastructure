#!/bin/bash
# Terraria Server (i-e) User Data Script
# - Install Docker and Docker Compose v2
# - Setup Terraria server environment

set -e

# Logging
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "=========================================="
echo "Terraria Server (i-e) Initialization Started"
echo "=========================================="

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
sudo mkdir -p /opt/terraria
sudo chown -R ec2-user:ec2-user /opt/terraria

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
echo "Cloning Terraria application from GitHub..."
cd /tmp
git clone -b master https://github.com/Kishax/kishax-terraria.git terraria-repo
sudo cp -r terraria-repo/* /opt/terraria/
rm -rf terraria-repo
sudo chown -R ec2-user:ec2-user /opt/terraria

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

# Generate .env file
cat > /opt/terraria/.env <<EOF
# ===================================
# Terraria Server Configuration
# ===================================

# S3 Configuration
AWS_REGION=$(get_param "/kishax/production/shared/aws_region")
S3_BUCKET=$(get_param "/kishax/production/terraria/s3_bucket")
S3_DOWNLOAD_ENABLED=$(get_param "/kishax/production/terraria/s3_download_enabled")

# TShock Server Configuration
SERVER_PASSWORD=$(get_secret_param "/kishax/production/terraria/server_password")
SERVER_PORT=$(get_param "/kishax/production/terraria/server_port")
MAX_SLOTS=$(get_param "/kishax/production/terraria/max_slots")
SERVER_NAME=$(get_param "/kishax/production/terraria/server_name")

# Discord Bot Configuration (TerrariaChatRelay)
DISCORD_BOT_TOKEN=$(get_secret_param "/kishax/production/terraria/discord_bot_token")
DISCORD_CHANNEL_ID=$(get_param "/kishax/production/terraria/discord_channel_id")
DISCORD_PRESENCE_ACTIVITY=$(get_param "/kishax/production/terraria/discord_presence_activity")

# TShock REST API Configuration
REST_API_ENABLED=$(get_param "/kishax/production/terraria/rest_api_enabled")
REST_API_PORT=$(get_param "/kishax/production/terraria/rest_api_port")
REST_API_TOKEN=$(get_secret_param "/kishax/production/terraria/rest_api_token")
REST_API_USERNAME=$(get_param "/kishax/production/terraria/rest_api_username")
REST_API_USERGROUP=$(get_param "/kishax/production/terraria/rest_api_usergroup")
EOF

sudo chmod 600 /opt/terraria/.env
sudo chown ec2-user:ec2-user /opt/terraria/.env

echo ".env file generated successfully from SSM Parameter Store"

# Download Docker image from S3
echo "Downloading Docker image from S3..."
aws s3 cp s3://kishax-production-docker-images/terraria/kishax-terraria-latest.tar.gz \
  /tmp/kishax-terraria-latest.tar.gz --region $REGION

# Load Docker image
echo "Loading Docker image..."
docker load < /tmp/kishax-terraria-latest.tar.gz

# Clean up
rm /tmp/kishax-terraria-latest.tar.gz

echo "Docker image loaded successfully"

# Create systemd service for Terraria server
cat > /etc/systemd/system/terraria.service <<'SERVICE'
[Unit]
Description=Terraria Server
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/terraria
ExecStart=/usr/local/lib/docker/cli-plugins/docker-compose up -d
ExecStop=/usr/local/lib/docker/cli-plugins/docker-compose down
User=ec2-user

[Install]
WantedBy=multi-user.target
SERVICE

echo "systemd service created at /etc/systemd/system/terraria.service"

# Enable and start Terraria service
echo "Enabling and starting Terraria service..."
systemctl daemon-reload
systemctl enable terraria.service
systemctl start terraria.service

# Check service status
echo "Terraria service status:"
systemctl status terraria.service --no-pager

echo "=========================================="
echo "Terraria Server (i-e) Initialization Complete"
echo "=========================================="
echo "Application deployed to: /opt/terraria"
echo "Service status: $(systemctl is-active terraria.service)"
