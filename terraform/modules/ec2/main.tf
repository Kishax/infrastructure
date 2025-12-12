# EC2 Module - Main Configuration

# Data source for latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Elastic IP for MC Server (i-a)
resource "aws_eip" "mc_server" {
  domain = "vpc"

  tags = {
    Name     = "kishax-${var.environment}-mc-server-eip"
    Instance = "i-a"
  }
}

# EC2 Instance: MC Server (i-a)
# - On-Demand instance (data protection priority)
# - t3.large for performance
# - 5 hours/day operation (22:00-27:00)
resource "aws_instance" "mc_server" {
  ami           = data.aws_ami.amazon_linux_2.id
  instance_type = "t3.large"
  
  subnet_id                   = var.public_subnet_ids[0]
  vpc_security_group_ids      = [var.mc_server_sg_id]
  associate_public_ip_address = true
  
  iam_instance_profile = var.mc_server_role_name
  key_name            = var.ec2_key_pair_name

  # User Data for Route53 update and Docker setup
  user_data = templatefile("${path.module}/user-data-mc-server.sh", {
    route53_zone_id = var.route53_zone_id
    mc_domain_name  = var.mc_domain_name
  })

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 50  # GB
    delete_on_termination = false  # データ保護
    encrypted             = true
  }

  # Additional EBS volume for Minecraft data
  ebs_block_device {
    device_name           = "/dev/sdf"
    volume_type           = "gp3"
    volume_size           = 100  # GB
    delete_on_termination = false  # データ保護
    encrypted             = true
  }

  tags = {
    Name     = "kishax-${var.environment}-mc-server"
    Instance = "i-a"
    Role     = "Minecraft-Server"
    Schedule = "22:00-27:00"
  }

  lifecycle {
    ignore_changes = [ami]  # AMI更新時の再作成を防ぐ
  }
}

# Attach Elastic IP to MC Server
resource "aws_eip_association" "mc_server" {
  instance_id   = aws_instance.mc_server.id
  allocation_id = aws_eip.mc_server.id
}

# EC2 Instance: API Server (i-b)
# - Spot instance for cost optimization
# - t3.small
# - 24/7 operation
resource "aws_spot_instance_request" "api_server" {
  ami           = data.aws_ami.amazon_linux_2.id
  instance_type = "t3.small"
  spot_type     = "persistent"  # 中断時に再起動
  
  subnet_id                   = var.private_subnet_ids[0]
  vpc_security_group_ids      = [var.api_server_sg_id]
  associate_public_ip_address = false  # Private subnet
  
  iam_instance_profile = var.api_server_role_name
  key_name            = var.ec2_key_pair_name

  # User Data for Docker and Redis setup
  user_data = file("${path.module}/user-data-api-server.sh")

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 30  # GB
    delete_on_termination = true
    encrypted             = true
  }

  tags = {
    Name     = "kishax-${var.environment}-api-server"
    Instance = "i-b"
    Role     = "API-Server-Redis"
    Schedule = "24/7"
  }

  lifecycle {
    ignore_changes = [ami]
  }
}

# EC2 Instance: Web Server (i-c)
# - Spot instance for cost optimization
# - t2.micro (smallest)
# - 24/7 operation
resource "aws_spot_instance_request" "web_server" {
  ami           = data.aws_ami.amazon_linux_2.id
  instance_type = "t2.micro"
  spot_type     = "persistent"
  
  subnet_id                   = var.public_subnet_ids[1]
  vpc_security_group_ids      = [var.web_server_sg_id]
  associate_public_ip_address = true  # CloudFront origin
  
  iam_instance_profile = var.web_server_role_name
  key_name            = var.ec2_key_pair_name

  # User Data for Docker setup
  user_data = file("${path.module}/user-data-web-server.sh")

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20  # GB
    delete_on_termination = true
    encrypted             = true
  }

  tags = {
    Name     = "kishax-${var.environment}-web-server"
    Instance = "i-c"
    Role     = "Web-Discord-Bot"
    Schedule = "24/7"
  }

  lifecycle {
    ignore_changes = [ami]
  }
}

# EC2 Instance: Jump Server (i-d)
# - On-Demand (rarely used, cost minimal)
# - t2.micro (smallest)
# - On-demand only (manual start/stop)
resource "aws_instance" "jump_server" {
  ami           = data.aws_ami.amazon_linux_2.id
  instance_type = "t2.micro"
  
  subnet_id                   = var.private_subnet_ids[1]
  vpc_security_group_ids      = [var.jump_server_sg_id]
  associate_public_ip_address = false  # Private subnet
  
  iam_instance_profile = var.jump_server_role_name
  key_name            = var.ec2_key_pair_name

  # User Data for PostgreSQL/MySQL client setup
  user_data = file("${path.module}/user-data-jump-server.sh")

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 10  # GB (minimal)
    delete_on_termination = true
    encrypted             = true
  }

  tags = {
    Name     = "kishax-${var.environment}-jump-server"
    Instance = "i-d"
    Role     = "RDS-Jump-Server"
    Schedule = "On-Demand"
  }

  lifecycle {
    ignore_changes = [ami]
  }

  # Start in stopped state by default
  # User can start manually when needed
}

# Outputs for spot instance IDs (need to extract from spot request)
data "aws_instance" "api_server" {
  instance_id = aws_spot_instance_request.api_server.spot_instance_id

  depends_on = [aws_spot_instance_request.api_server]
}

data "aws_instance" "web_server" {
  instance_id = aws_spot_instance_request.web_server.spot_instance_id

  depends_on = [aws_spot_instance_request.web_server]
}
