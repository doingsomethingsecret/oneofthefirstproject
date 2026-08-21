variable "vpc_id" {}
variable "app_id" {}
variable "jenkins_id" {}
variable "sonarqube_id" {}
variable "monitoring_id" {}
variable "alb_sg_id" {}
variable "public_subnet_ids" {}
variable "certificate_arn" { default = "" }

resource "aws_lb" "main" {
  name               = "atlas-ai-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.public_subnet_ids
  access_logs {
    bucket  = aws_s3_bucket.alb_logs.bucket
    prefix  = "alb-logs"
    enabled = true
  }
  tags = { Name = "atlas-ai-alb" }
}

resource "aws_s3_bucket" "alb_logs" {
  bucket        = "atlas-ai-alb-logs-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  policy = data.aws_iam_policy_document.alb_logs.json
}

data "aws_iam_policy_document" "alb_logs" {
  statement {
    effect    = "Allow"
    principals {
      type        = "AWS"
      identifiers = [data.aws_elb_service_account.main.arn]
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.alb_logs.arn}/*"]
  }
}

data "aws_elb_service_account" "main" {}
data "aws_caller_identity" "current" {}

resource "aws_lb_target_group" "app" {
  name        = "atlas-ai-app-tg"
  port        = 5000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"
  health_check {
    path                = "/api/health"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
  tags = { Name = "atlas-ai-app-tg" }
}

resource "aws_lb_target_group" "jenkins" {
  name        = "atlas-ai-jenkins-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"
  health_check {
    path                = "/login"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
  tags = { Name = "atlas-ai-jenkins-tg" }
}

resource "aws_lb_target_group" "sonarqube" {
  name        = "atlas-ai-sonarqube-tg"
  port        = 9000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"
  health_check {
    path                = "/api/system/status"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
  tags = { Name = "atlas-ai-sonarqube-tg" }
}


resource "aws_lb_target_group_attachment" "app" {
  target_group_arn = aws_lb_target_group.app.arn
  target_id        = var.app_id
  port             = 5000
}

resource "aws_lb_target_group_attachment" "jenkins" {
  target_group_arn = aws_lb_target_group.jenkins.arn
  target_id        = var.jenkins_id
  port             = 8080
}

resource "aws_lb_target_group_attachment" "sonarqube" {
  target_group_arn = aws_lb_target_group.sonarqube.arn
  target_id        = var.sonarqube_id
  port             = 9000
}

resource "aws_lb_target_group_attachment" "monitoring" {
  target_group_arn = aws_lb_target_group.grafana.arn
  target_id        = var.monitoring_id
  port             = 3000
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

resource "aws_lb_listener" "https" {
  count           = var.certificate_arn != "" ? 1 : 0
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.certificate_arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

resource "aws_lb_listener_rule" "http_redirect" {
  count        = var.certificate_arn != "" ? 1 : 0
  listener_arn = aws_lb_listener.http.arn
  priority     = 5
  action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
  condition {
    path_pattern {
      values = ["/*"]
    }
  }
}

resource "aws_lb_listener_rule" "jenkins_http" {
  count        = var.certificate_arn == "" ? 1 : 0
  listener_arn = aws_lb_listener.http.arn
  priority     = 10
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.jenkins.arn
  }
  condition {
    path_pattern {
      values = ["/jenkins/*"]
    }
  }
}

resource "aws_lb_listener_rule" "sonarqube_http" {
  count        = var.certificate_arn == "" ? 1 : 0
  listener_arn = aws_lb_listener.http.arn
  priority     = 20
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.sonarqube.arn
  }
  condition {
    path_pattern {
      values = ["/sonar/*"]
    }
  }
}

resource "aws_lb_listener_rule" "grafana_http" {
  count        = var.certificate_arn == "" ? 1 : 0
  listener_arn = aws_lb_listener.http.arn
  priority     = 30
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.grafana.arn
  }
  condition {
    path_pattern {
      values = ["/grafana/*"]
    }
  }
}

resource "aws_lb_listener_rule" "jenkins_https" {
  count        = var.certificate_arn != "" ? 1 : 0
  listener_arn = aws_lb_listener.https[0].arn
  priority     = 10
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.jenkins.arn
  }
  condition {
    path_pattern {
      values = ["/jenkins/*"]
    }
  }
}

resource "aws_lb_listener_rule" "sonarqube_https" {
  count        = var.certificate_arn != "" ? 1 : 0
  listener_arn = aws_lb_listener.https[0].arn
  priority     = 20
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.sonarqube.arn
  }
  condition {
    path_pattern {
      values = ["/sonar/*"]
    }
  }
}

resource "aws_lb_listener_rule" "grafana_https" {
  count        = var.certificate_arn != "" ? 1 : 0
  listener_arn = aws_lb_listener.https[0].arn
  priority     = 30
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.grafana.arn
  }
  condition {
    path_pattern {
      values = ["/grafana/*"]
    }
  }
}

output "alb_dns_name" { value = aws_lb.main.dns_name }
output "alb_zone_id"  { value = aws_lb.main.zone_id }

resource "aws_lb_target_group" "prometheus" {
  name        = "atlas-ai-prometheus-tg"
  port        = 9090
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"
  health_check {
    path                = "/"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
  tags = { Name = "atlas-ai-prometheus-tg" }
}

resource "aws_lb_target_group_attachment" "prometheus" {
  target_group_arn = aws_lb_target_group.prometheus.arn
  target_id        = var.monitoring_id
  port             = 9090
}

resource "aws_lb_listener_rule" "prometheus_http" {
  count        = var.certificate_arn == "" ? 1 : 0
  listener_arn = aws_lb_listener.http.arn
  priority     = 40
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.prometheus.arn
  }
  condition {
    path_pattern {
      values = ["/prometheus/*"]
    }
  }
}

resource "aws_lb_listener_rule" "prometheus_https" {
  count        = var.certificate_arn != "" ? 1 : 0
  listener_arn = aws_lb_listener.https[0].arn
  priority     = 40
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.prometheus.arn
  }
  condition {
    path_pattern {
      values = ["/prometheus/*"]
    }
  }
}

resource "aws_lb_target_group" "grafana" {
  name        = "atlas-ai-grafana-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"
  health_check {
    path                = "/api/health"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
  tags = { Name = "atlas-ai-grafana-tg" }
}

resource "aws_lb_target_group_attachment" "grafana" {
  target_group_arn = aws_lb_target_group.grafana.arn
  target_id        = var.monitoring_id
  port             = 3000
}
