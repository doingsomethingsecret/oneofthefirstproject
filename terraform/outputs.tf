output "bastion_public_ip" { value = module.compute.bastion_public_ip }
output "alb_dns_name"      { value = module.loadbalancer.alb_dns_name }
output "alb_zone_id"       { value = module.loadbalancer.alb_zone_id }

output "service_urls" {
  value = {
    app        = "http://${module.loadbalancer.alb_dns_name}/"
    jenkins    = "http://${module.loadbalancer.alb_dns_name}/jenkins/"
    sonarqube  = "http://${module.loadbalancer.alb_dns_name}/sonar/"
    grafana    = "http://${module.loadbalancer.alb_dns_name}/grafana/"
    prometheus = "http://${module.loadbalancer.alb_dns_name}/prometheus/"
  }
}

output "ssh_command" { value = "ssh -i /home/unknown/Documents/tkxel_devops_project.pem ubuntu@${module.compute.bastion_public_ip}" }

output "private_ips" {
  value = {
    app        = module.compute.app_private_ip
    jenkins    = module.compute.jenkins_private_ip
    sonarqube  = module.compute.sonarqube_private_ip
    monitoring = module.compute.monitoring_private_ip
  }
}

output "vpc_id"            { value = module.networking.vpc_id }
output "public_subnet_id"  { value = module.networking.public_subnet_id }
output "private_subnet_id" { value = module.networking.private_subnet_id }
