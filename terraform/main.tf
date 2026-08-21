module "networking" {
  source              = "./modules/networking"
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidr  = var.public_subnet_cidr
  private_subnet_cidr = var.private_subnet_cidr
}

module "security" {
  source = "./modules/security"
  vpc_id = module.networking.vpc_id
  ssh_cidr = var.ssh_cidr
}

module "iam" {
  source       = "./modules/iam"
  environment  = var.environment
  project_name = var.project_name
}

module "compute" {
  source                = "./modules/compute"
  ami                   = data.aws_ami.ubuntu.id
  key_name              = var.key_name
  instance_profile_name = module.iam.instance_profile_name
  vpc_id                = module.networking.vpc_id
  public_subnet_id      = module.networking.public_subnet_id
  private_subnet_id     = module.networking.private_subnet_id
  bastion_sg_id         = module.security.bastion_sg_id
  app_sg_id             = module.security.app_sg_id
  jenkins_sg_id         = module.security.jenkins_sg_id
  sonarqube_sg_id       = module.security.sonarqube_sg_id
  monitoring_sg_id      = module.security.monitoring_sg_id
}

module "loadbalancer" {
  source            = "./modules/loadbalancer"
  vpc_id            = module.networking.vpc_id
  app_id            = module.compute.app_id
  jenkins_id        = module.compute.jenkins_id
  sonarqube_id      = module.compute.sonarqube_id
  monitoring_id     = module.compute.monitoring_id
  alb_sg_id         = module.security.alb_sg_id
  public_subnet_ids = module.networking.public_subnet_ids
  certificate_arn   = var.certificate_arn
}
