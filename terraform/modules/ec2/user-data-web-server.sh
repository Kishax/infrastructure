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

# Download .env file from S3
echo "Downloading .env file from S3..."
aws s3 cp s3://kishax-production-env-files/i-c/web/.env /opt/web/.env --region $REGION
sudo chmod 600 /opt/web/.env
sudo chown ec2-user:ec2-user /opt/web/.env

echo ".env file downloaded successfully"

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
