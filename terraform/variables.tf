variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
}

variable "key_name" {
  description = "AWS EC2 Key Pair name for SSH access"
  type        = string
}

variable "key_path" {
  description = "Local path to SSH private key file (.pem)"
  type        = string
}

variable "environment" {
  description = "Environment name (dev/staging/prod)"
  type        = string
}

variable "project_name" {
  description = "Project name used for tagging resources"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for private subnet"
  type        = string
  default     = "10.0.3.0/24"
}

variable "certificate_arn" {
  description = "ACM Certificate ARN for HTTPS (leave empty for HTTP only)"
  type        = string
  default     = ""
}

variable "ssh_cidr" {
  description = "CIDR block allowed to access Bastion SSH (0.0.0.0/0 = public, X.X.X.X/32 = specific IP)"
  type        = string
  default     = "0.0.0.0/0"
}
