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

# Download .env file from S3
echo "Downloading .env file from S3..."
aws s3 cp s3://kishax-production-env-files/i-a/mc/.env /opt/mc/.env --region $REGION
sudo chmod 600 /opt/mc/.env
sudo chown ec2-user:ec2-user /opt/mc/.env

echo ".env file downloaded successfully"

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
