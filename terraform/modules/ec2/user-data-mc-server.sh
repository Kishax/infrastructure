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
yum install -y docker
systemctl start docker
systemctl enable docker

# Install Docker Compose
echo "Installing Docker Compose..."
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Create minecraft user
echo "Creating minecraft user..."
useradd -m -s /bin/bash minecraft
usermod -aG docker minecraft

# Create directories
echo "Creating application directories..."
mkdir -p /opt/mc/data
mkdir -p /opt/mc/images
chown -R minecraft:minecraft /opt/mc

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
cp -r mc-repo/* /opt/mc/
rm -rf mc-repo
chown -R minecraft:minecraft /opt/mc

# Download .env file from S3
echo "Downloading .env file from S3..."
aws s3 cp s3://kishax-production-env-files/i-a/mc/.env /opt/mc/.env --region $REGION
chmod 600 /opt/mc/.env
chown minecraft:minecraft /opt/mc/.env

echo ".env file downloaded successfully"

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
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
User=minecraft

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
