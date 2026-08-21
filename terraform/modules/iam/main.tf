# IAM Role + Instance Profile for EC2 instances


variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "atlas-ai"
}

# IAM Role - Gives EC2 instances permission to access AWS services
resource "aws_iam_role" "app" {
  name = "${var.project_name}-${var.environment}-app-role"

  # Who can use this role? EC2 instances can assume it
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = { Name = "${var.project_name}-${var.environment}-app-role" }
}

# SSM Access - For keyless SSH via AWS Systems Manager
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# CloudWatch Access - For sending metrics to CloudWatch
resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Instance Profile - Wrapper to attach IAM Role to EC2 instances
resource "aws_iam_instance_profile" "app" {
  name = "${var.project_name}-${var.environment}-app-profile"
  role = aws_iam_role.app.name
}

# Output
output "instance_profile_name" { value = aws_iam_instance_profile.app.name }
