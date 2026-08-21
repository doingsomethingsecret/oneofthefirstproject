# ===========================================
# NETWORKING MODULE
# Creates: VPC, Subnets, Internet Gateway, NAT Gateway, Route Tables
# ===========================================

variable "vpc_cidr" {
  description = "VPC IP address range"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "Public subnet IP range"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "Private subnet IP range"
  type        = string
  default     = "10.0.3.0/24"
}

# VPC - Our isolated network in AWS
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "atlas-ai-vpc" }
}

# Internet Gateway - Connects VPC to internet
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "atlas-ai-igw" }
}

# Public Subnet 1 - Bastion + ALB (has public IP)
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[0]
  tags = { Name = "atlas-ai-public-1", Tier = "public" }
}

# Public Subnet 2 - ALB High Availability (different AZ)
resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, 4)
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[1]
  tags = { Name = "atlas-ai-public-2", Tier = "public" }
}

# Private Subnet - App, Jenkins, SonarQube, Monitoring (no public IP)
resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_cidr
  map_public_ip_on_launch = false
  availability_zone       = data.aws_availability_zones.available.names[0]
  tags = { Name = "atlas-ai-private", Tier = "private" }
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  domain      = "vpc"
  depends_on  = [aws_internet_gateway.igw]
  tags        = { Name = "atlas-ai-nat-eip" }
}

# NAT Gateway - Private subnet can access internet through this
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_1.id
  tags         = { Name = "atlas-ai-nat-gw" }
}

# Public Route Table - Traffic from public subnet goes through Internet Gateway
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "atlas-ai-public-rt" }
}

# Private Route Table - Traffic from private subnet goes through NAT Gateway
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = { Name = "atlas-ai-private-rt" }
}

# Connect public subnets to public route table
resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

# Connect private subnet to private route table
resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# Get available AZs
data "aws_availability_zones" "available" {
  state = "available"
}

# Outputs
output "vpc_id"            { value = aws_vpc.main.id }
output "public_subnet_id"  { value = aws_subnet.public_1.id }
output "public_subnet_ids" { value = [aws_subnet.public_1.id, aws_subnet.public_2.id] }
output "private_subnet_id" { value = aws_subnet.private.id }
