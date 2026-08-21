# EC2 Instances (Bastion, App, Jenkins, SonarQube, Monitoring)


variable "ami" {
  description = "AMI ID for EC2 instances"
  type        = string
}

variable "key_name" {
  description = "AWS Key Pair name for SSH"
  type        = string
}

variable "instance_profile_name" {
  description = "IAM Instance Profile name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnet_id" {
  description = "Public subnet ID for Bastion"
  type        = string
}

variable "private_subnet_id" {
  description = "Private subnet ID for other servers"
  type        = string
}

variable "bastion_sg_id" {
  description = "Bastion security group ID"
  type        = string
}

variable "app_sg_id" {
  description = "App security group ID"
  type        = string
}

variable "jenkins_sg_id" {
  description = "Jenkins security group ID"
  type        = string
}

variable "sonarqube_sg_id" {
  description = "SonarQube security group ID"
  type        = string
}

variable "monitoring_sg_id" {
  description = "Monitoring security group ID"
  type        = string
}

# Common script that runs on all instances on first boot
locals {
  common_user_data = <<-EOF
    #!/bin/bash
    apt-get update && apt-get upgrade -y
    apt-get install -y curl wget git unzip htop
    snap install amazon-ssm-agent --classic
    systemctl enable --now amazon-ssm-agent
  EOF
}

# Bastion Host - Public Subnet (Jump Server for SSH)
resource "aws_instance" "bastion" {
  ami                         = var.ami
  instance_type               = "t3.micro"
  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids      = [var.bastion_sg_id]
  key_name                    = var.key_name
  associate_public_ip_address = true
  iam_instance_profile        = var.instance_profile_name
  user_data                   = local.common_user_data

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 8
    delete_on_termination = true
    encrypted             = true
  }

  tags = { Name = "bastion-host", Role = "bastion" }
}

# App Server - Private Subnet (Flask Application)
resource "aws_instance" "app" {
  ami                    = var.ami
  instance_type          = "t3.small"
  subnet_id              = var.private_subnet_id
  vpc_security_group_ids = [var.app_sg_id]
  key_name               = var.key_name
  iam_instance_profile   = var.instance_profile_name

  user_data = <<-EOF
    #!/bin/bash
    ${local.common_user_data}
    apt-get install -y docker.io python3 python3-pip
    systemctl start docker && systemctl enable docker
    usermod -aG docker ubuntu
  EOF

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    delete_on_termination = true
    encrypted             = true
  }

  tags = { Name = "app-server", Role = "app" }
}

# Jenkins Server - Private Subnet (CI/CD)
resource "aws_instance" "jenkins" {
  ami                    = var.ami
  instance_type          = "t3.small"
  subnet_id              = var.private_subnet_id
  vpc_security_group_ids = [var.jenkins_sg_id]
  key_name               = var.key_name
  iam_instance_profile   = var.instance_profile_name

  user_data = <<-EOF
    #!/bin/bash
    ${local.common_user_data}
    apt-get install -y docker.io openjdk-17-jre
    systemctl start docker && systemctl enable docker
    usermod -aG docker ubuntu
  EOF

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 30
    delete_on_termination = true
    encrypted             = true
  }

  tags = { Name = "jenkins-server", Role = "jenkins" }
}

# SonarQube Server - Private Subnet (Code Quality)
resource "aws_instance" "sonarqube" {
  ami                    = var.ami
  instance_type          = "t3.small"
  subnet_id              = var.private_subnet_id
  vpc_security_group_ids = [var.sonarqube_sg_id]
  key_name               = var.key_name
  iam_instance_profile   = var.instance_profile_name

  user_data = <<-EOF
    #!/bin/bash
    ${local.common_user_data}
    apt-get install -y docker.io
    systemctl start docker && systemctl enable docker
    usermod -aG docker ubuntu
  EOF

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 30
    delete_on_termination = true
    encrypted             = true
  }

  tags = { Name = "sonarqube-server", Role = "sonarqube" }
}

# Monitoring Server - Private Subnet (Prometheus + Grafana)
resource "aws_instance" "monitoring" {
  ami                    = var.ami
  instance_type          = "t3.small"
  subnet_id              = var.private_subnet_id
  vpc_security_group_ids = [var.monitoring_sg_id]
  key_name               = var.key_name
  iam_instance_profile   = var.instance_profile_name

  user_data = <<-EOF
    #!/bin/bash
    ${local.common_user_data}
    apt-get install -y docker.io
    systemctl start docker && systemctl enable docker
    usermod -aG docker ubuntu
  EOF

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    delete_on_termination = true
    encrypted             = true
  }

  tags = { Name = "monitoring-server", Role = "monitoring" }
}

# Outputs
output "bastion_public_ip"     { value = aws_instance.bastion.public_ip }
output "app_id"                { value = aws_instance.app.id }
output "app_private_ip"        { value = aws_instance.app.private_ip }
output "jenkins_id"            { value = aws_instance.jenkins.id }
output "jenkins_private_ip"    { value = aws_instance.jenkins.private_ip }
output "sonarqube_id"          { value = aws_instance.sonarqube.id }
output "sonarqube_private_ip"  { value = aws_instance.sonarqube.private_ip }
output "monitoring_id"         { value = aws_instance.monitoring.id }
output "monitoring_private_ip" { value = aws_instance.monitoring.private_ip }
