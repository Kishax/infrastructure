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
mkdir -p /opt/minecraft/data
mkdir -p /opt/minecraft/images
chown -R minecraft:minecraft /opt/minecraft

# Install AWS CLI (if not already installed)
if ! command -v aws &> /dev/null; then
    echo "Installing AWS CLI..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    ./aws/install
    rm -rf awscliv2.zip aws
fi

# Create systemd service for Minecraft server (optional)
cat > /etc/systemd/system/minecraft.service <<'SERVICE'
[Unit]
Description=Minecraft Server
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/minecraft
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
User=minecraft

[Install]
WantedBy=multi-user.target
SERVICE

# Note: Docker Compose file should be deployed separately
echo "systemd service created at /etc/systemd/system/minecraft.service"

echo "========================================="
echo "MC Server (i-a) Initialization Complete"
echo "========================================="
echo "Next steps:"
echo "1. Deploy docker-compose.yml to /opt/minecraft/"
echo "2. Start service: systemctl start minecraft"
