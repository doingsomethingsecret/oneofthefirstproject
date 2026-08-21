# Terraform Infrastructure

## Optimized Production Architecture

```
VPC: 10.0.0.0/16
├── Public Subnet: 10.0.1.0/24
│   └── Bastion Host (t3.micro)
└── Private Subnet: 10.0.2.0/24
    ├── App Server (t3.small)
    ├── Jenkins Server (t3.small)
    ├── SonarQube Server (t3.small)
    └── Monitoring Server (t3.small)

ALB (Application Load Balancer)
├── HTTP (80) → Redirects to HTTPS
└── HTTPS (443) → Path-based routing
    ├── /           → App :5000
    ├── /jenkins/   → Jenkins :8080
    ├── /sonar/     → SonarQube :9000
    ├── /grafana/   → Grafana :3000
    └── /prometheus/ → Prometheus :9090
```

## Security Groups

- **bastion-sg**: SSH (22) from 0.0.0.0/0
- **alb-sg**: HTTP (80) + HTTPS (443) from 0.0.0.0/0
- **app-sg**: 5000 from ALB, 22 from Bastion
- **jenkins-sg**: 8080 from ALB, 22 from Bastion
- **sonarqube-sg**: 9000 from ALB, 22 from Bastion
- **monitoring-sg**: 3000 + 9090 from ALB, 22 from Bastion

## Resources Created

- VPC with public/private subnets
- Internet Gateway + NAT Gateway
- 5 EC2 instances (Ubuntu 22.04)
- Application Load Balancer with target groups
- ALB access logs (S3)
- Security Groups (least privilege)

## Usage

```bash
# Initialize
terraform init

# Plan
terraform plan -var="certificate_arn="

# Deploy (HTTP only - no certificate)
terraform apply -var="certificate_arn="

# Deploy with HTTPS (provide ACM certificate ARN)
terraform apply -var="certificate_arn=arn:aws:acm:ap-south-1:123456789:certificate/xxx"
```

## Outputs

- `alb_dns_name`: ALB DNS name for accessing services
- `service_urls`: Map of all service URLs
- `ssh_command`: SSH command to bastion host
- `private_ips`: Private IPs of all servers
