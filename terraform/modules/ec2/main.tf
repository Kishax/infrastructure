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

# --- Elastic IPs ---

# Elastic IP for MC Server (i-a)
resource "aws_eip" "mc_server" {
  domain = "vpc"

  tags = {
    Name     = "kishax-${var.environment}-mc-server-eip"
    Instance = "i-a"
  }
}

# Elastic IP for API Server (i-b)
resource "aws_eip" "api_server" {
  domain = "vpc"

  tags = {
    Name     = "kishax-${var.environment}-api-server-eip"
    Instance = "i-b"
  }
}

# Elastic IP for Web Server (i-c)
resource "aws_eip" "web_server" {
  domain = "vpc"

  tags = {
    Name     = "kishax-${var.environment}-web-server-eip"
    Instance = "i-c"
  }
}

# Elastic IP for Terraria Server (i-e)
resource "aws_eip" "terraria_server" {
  domain = "vpc"

  tags = {
    Name     = "kishax-${var.environment}-terraria-server-eip"
    Instance = "i-e"
  }
}

# --- EC2 Instances ---

# EC2 Instance: MC Server (i-a)
resource "aws_instance" "mc_server" {
  ami           = data.aws_ami.amazon_linux_2.id
  instance_type = "t3.large"
  
  subnet_id                   = var.public_subnet_ids[0]
  vpc_security_group_ids      = [var.mc_server_sg_id]
  # associate_public_ip_address = true # EIPを使用するため削除
  
  iam_instance_profile = var.mc_server_instance_profile
  key_name             = var.ec2_key_pair_name

  user_data = templatefile("${path.module}/user-data-mc-server.sh", {
    route53_zone_id = var.route53_zone_id
    mc_domain_name  = var.mc_domain_name
  })

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 50
    delete_on_termination = false
    encrypted             = true
  }

  ebs_block_device {
    device_name           = "/dev/sdf"
    volume_type           = "gp3"
    volume_size           = 100
    delete_on_termination = false
    encrypted             = true
  }

  tags = {
    Name     = "kishax-${var.environment}-mc-server"
    Instance = "i-a"
    Role     = "Minecraft-Server"
    Schedule = "22:00-27:00"
  }

  lifecycle {
    ignore_changes = [ami]
  }
}

# EC2 Instance: API Server (i-b)
resource "aws_instance" "api_server" {
  ami           = data.aws_ami.amazon_linux_2.id
  instance_type = "t3.small"

  subnet_id                   = var.public_subnet_ids[0]
  vpc_security_group_ids      = [var.api_server_sg_id]
  # associate_public_ip_address = true # EIPを使用するため削除

  iam_instance_profile = var.api_server_instance_profile
  key_name            = var.ec2_key_pair_name

  user_data = file("${path.module}/user-data-api-server.sh")

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 30
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
resource "aws_instance" "web_server" {
  ami           = data.aws_ami.amazon_linux_2.id
  instance_type = "t2.micro"

  subnet_id                   = var.public_subnet_ids[1]
  vpc_security_group_ids      = [var.web_server_sg_id]
  # associate_public_ip_address = true # EIPを使用するため削除

  iam_instance_profile = var.web_server_instance_profile
  key_name            = var.ec2_key_pair_name

  user_data = templatefile("${path.module}/user-data-web-server.sh", {
    route53_zone_id  = var.route53_zone_id
    web_domain_name  = var.web_domain_name
  })

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
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
resource "aws_instance" "jump_server" {
  ami           = data.aws_ami.amazon_linux_2.id
  instance_type = "t2.micro"
  
  subnet_id                   = var.public_subnet_ids[0]
  vpc_security_group_ids      = [var.jump_server_sg_id]
  associate_public_ip_address = true  # 踏み台は一時的な利用のためEIP化せず維持
  
  iam_instance_profile = var.jump_server_instance_profile
  key_name            = var.ec2_key_pair_name

  user_data = file("${path.module}/user-data-jump-server.sh")

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 10
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
}

# EC2 Instance: Terraria Server (i-e)
resource "aws_instance" "terraria_server" {
  ami           = data.aws_ami.amazon_linux_2.id
  instance_type = "t3.small"

  subnet_id                   = var.public_subnet_ids[0]
  vpc_security_group_ids      = [var.terraria_server_sg_id]
  # associate_public_ip_address = true # EIPを使用するため削除

  iam_instance_profile = var.terraria_server_instance_profile
  key_name            = var.ec2_key_pair_name

  user_data = file("${path.module}/user-data-terraria-server.sh")

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    delete_on_termination = false
    encrypted             = true
  }

  tags = {
    Name     = "kishax-${var.environment}-terraria-server"
    Instance = "i-e"
    Role     = "Terraria-Server"
    Schedule = "On-Demand"
  }

  lifecycle {
    ignore_changes = [ami]
  }
}

# --- EIP Associations ---

resource "aws_eip_association" "mc_server" {
  instance_id   = aws_instance.mc_server.id
  allocation_id = aws_eip.mc_server.id
}

resource "aws_eip_association" "api_server" {
  instance_id   = aws_instance.api_server.id
  allocation_id = aws_eip.api_server.id
}

resource "aws_eip_association" "web_server" {
  instance_id   = aws_instance.web_server.id
  allocation_id = aws_eip.web_server.id
}

resource "aws_eip_association" "terraria_server" {
  instance_id   = aws_instance.terraria_server.id
  allocation_id = aws_eip.terraria_server.id
}