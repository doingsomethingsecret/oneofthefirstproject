# ═══════════════════════════════════════════════════════════════════════
#  Terraform "settings" file  (terraform.tf)
# ──────────────────────────────────────────────────────────────────────
#  Yeh file Terraform ko batati hai ki:
#   (1) kaunse Terraform version chahiye  (>= 1.0)
#   (2) kaunse AWS provider (plugin) chahiye  (hashicorp/aws ~> 6.0)
#   (3) state file kahan store hone chahiye  (S3 bucket + locking)
#   (4) provider ka basic config (region + default tags)
#   (5) base AMI kaun sa lena hai (Ubuntu 22.04)
#
#  NOTE: State file S3 bucket `tkxel-devops-bucket` honi chahiye,
#        jiska naam pehle se AWS account me banaya hoga (manual ya dusri
#        Terraform run se). Agar nahi hai → `terraform init` fail karega.
# ═══════════════════════════════════════════════════════════════════════
terraform {
  # Terraform CLI ka minimum version (1.0 ya usse nayi).
  required_version = ">= 1.0"

  required_providers {
    # AWS resources (EC2, VPC, IAM, ALB, ...) banane ke liye zaroori plugin.
    aws = {
      source  = "hashicorp/aws"   # official HashiCorp AWS provider
      version = "~> 6.0"          # sirf 6.x series (6.0, 6.1, 6.60...) leta hai
    }
  }

  # ── Remote state: state file S3 me store hoti hai (team sharing + backup) ──
  backend "s3" {
    bucket       = "tkxel-devops-bucket"           # state file yahan save hogi
    key          = "tkxel-devops/terraform.tfstate" # state file ka path bucket ke andar
    region       = "ap-south-1"                      # Mumbai region
    encrypt      = true                              # state file encrypt (SSE-S3)
    use_lockfile = true                              # state locking ON → ek samaan time ek hi deploy
  }
}

# ── AWS provider config ─────────────────────────────────────────────────
provider "aws" {
  region = "ap-south-1"   # sabhi resources yahi Mumbai region me banenge

  # Har resource ko yeh default tags milenge (billing/search ke liye bahut kaam aate hain).
  default_tags {
    tags = {
      Project     = "atlas-ai"    # project ka naam
      Environment = "dev"         # dev / staging / prod
      ManagedBy   = "Terraform"   # haath se na bana, Terraform ne bana
    }
  }
}

# ── Base AMI: hamesha Ubuntu 22.04 (Jammy) ki sabse nayi image lena ───────
#   is `data` se hum ek AMI ID pata karte hain, jo baad me `compute` module
#   ko di jaati hai (`ami = data.aws_ami.ubuntu.id`).
data "aws_ami" "ubuntu" {
  most_recent = true                       # sabse pehle/latest image
  owners      = ["099720109477"]           # yeh number = Canonical (Ubuntu official)

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]  # "Jammy" = 22.04
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]                       # standard virtualization
  }
}

# ── (Optional) Root-level input variable ─────────────────────────────────
#  Agar aap HTTPS (SSL) chaahte hain to ACM certificate ARN provide karein.
#  Varna chhod dein / blank rakhein → sirf HTTP (80) ka traffic chalega.
#  Yeh value seedha `loadbalancer` module ko milti hai (main.tf dekhein).

