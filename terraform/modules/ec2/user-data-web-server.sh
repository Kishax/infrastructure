#!/bin/bash
# Web Server (i-c) User Data Script
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

# Create web user
echo "Creating web user..."
useradd -m -s /bin/bash web
usermod -aG docker web

# Create directories
echo "Creating application directories..."
mkdir -p /opt/web
mkdir -p /opt/discord
chown -R web:web /opt/web /opt/discord

# Install AWS CLI (if not already installed)
if ! command -v aws &> /dev/null; then
    echo "Installing AWS CLI..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    ./aws/install
    rm -rf awscliv2.zip aws
fi

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
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
User=web

[Install]
WantedBy=multi-user.target
SERVICE

# Create systemd service for Discord Bot
cat > /etc/systemd/system/discord.service <<'SERVICE'
[Unit]
Description=Discord Bot
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/discord
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
User=web

[Install]
WantedBy=multi-user.target
SERVICE

echo "systemd services created"

echo "========================================="
echo "Web Server (i-c) Initialization Complete"
echo "========================================="
echo "Next steps:"
echo "1. Deploy docker-compose.yml to /opt/web/ and /opt/discord/"
echo "2. Start services:"
echo "   - systemctl start web"
echo "   - systemctl start discord"
