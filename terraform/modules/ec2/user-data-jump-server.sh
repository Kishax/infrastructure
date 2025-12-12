#!/bin/bash
# Jump Server (i-d) User Data Script
# - Minimal setup for RDS access via SSM Session Manager

set -e

# Logging
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "========================================="
echo "Jump Server (i-d) Initialization Started"
echo "========================================="

# Get instance metadata
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)

echo "Instance ID: $INSTANCE_ID"
echo "Region: $REGION"

# System update
echo "Updating system packages..."
yum update -y

# Install PostgreSQL client
echo "Installing PostgreSQL client..."
yum install -y postgresql

# Install MySQL client
echo "Installing MySQL client..."
yum install -y mysql

# Install AWS CLI (if not already installed)
if ! command -v aws &> /dev/null; then
    echo "Installing AWS CLI..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    ./aws/install
    rm -rf awscliv2.zip aws
fi

# Install SSM Agent (usually pre-installed on Amazon Linux 2)
echo "Ensuring SSM Agent is running..."
systemctl status amazon-ssm-agent || systemctl start amazon-ssm-agent
systemctl enable amazon-ssm-agent

echo "========================================="
echo "Jump Server (i-d) Initialization Complete"
echo "========================================="
echo "Access via SSM Session Manager:"
echo "aws ssm start-session --target $INSTANCE_ID --region $REGION"
echo ""
echo "Connect to PostgreSQL:"
echo "psql -h <rds-endpoint> -U <username> -d <database>"
echo ""
echo "Connect to MySQL:"
echo "mysql -h <rds-endpoint> -u <username> -p"
