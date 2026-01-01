#!/bin/bash
# User Data for Terraria Server (i-e)
# Minimal setup - no Docker, native execution

set -e

# Update system packages
yum update -y

# Install basic tools
yum install -y \
  wget \
  unzip \
  screen \
  tmux \
  vim \
  git

# Create Terraria directory
mkdir -p /opt/terraria
chown ec2-user:ec2-user /opt/terraria

# Log completion
echo "Terraria Server user-data setup completed at $(date)" >> /var/log/user-data.log
