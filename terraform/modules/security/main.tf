#  Security Groups (Firewall Rules)

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "ssh_cidr" {
  description = "CIDR block allowed to access Bastion SSH"
  type        = string
}

# Bastion SG - SSH from anywhere (Lab only!)
resource "aws_security_group" "bastion" {
  name   = "bastion-sg"
  vpc_id = var.vpc_id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_cidr]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "bastion-sg" }
}

# ALB SG - HTTP/HTTPS from internet
resource "aws_security_group" "alb" {
  name   = "alb-sg"
  vpc_id = var.vpc_id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "alb-sg" }
}

# App SG - SSH from Bastion, HTTP from ALB
resource "aws_security_group" "app" {
  name   = "app-sg"
  vpc_id = var.vpc_id
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }
  ingress {
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "app-sg" }
}

# Jenkins SG - SSH from Bastion, HTTP from ALB
resource "aws_security_group" "jenkins" {
  name   = "jenkins-sg"
  vpc_id = var.vpc_id
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }
  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "jenkins-sg" }
}

# SonarQube SG - SSH from Bastion, HTTP from ALB
resource "aws_security_group" "sonarqube" {
  name   = "sonarqube-sg"
  vpc_id = var.vpc_id
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }
  ingress {
    from_port       = 9000
    to_port         = 9000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "sonarqube-sg" }
}

# Monitoring SG - SSH from Bastion, HTTP from ALB
resource "aws_security_group" "monitoring" {
  name   = "monitoring-sg"
  vpc_id = var.vpc_id
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }
  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  ingress {
    from_port       = 9090
    to_port         = 9090
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "monitoring-sg" }
}

# Outputs
output "bastion_sg_id"    { value = aws_security_group.bastion.id }
output "alb_sg_id"        { value = aws_security_group.alb.id }
output "app_sg_id"        { value = aws_security_group.app.id }
output "jenkins_sg_id"    { value = aws_security_group.jenkins.id }
output "sonarqube_sg_id"  { value = aws_security_group.sonarqube.id }
output "monitoring_sg_id" { value = aws_security_group.monitoring.id }
