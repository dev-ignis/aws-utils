# ACM Certificate
resource "aws_acm_certificate" "main" {
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}", "staging.api.${var.domain_name}"]
  validation_method         = "DNS"
  
  tags = {
    Name        = "${var.instance_name}-cert"
    Environment = var.environment
  }

  lifecycle {
    create_before_destroy = true
  }
}

# DNS Validation Records
resource "aws_route53_record" "cert_validation" {
  for_each = var.skip_route53 ? {} : {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  lifecycle {
    create_before_destroy = true
    prevent_destroy = false
  }

  allow_overwrite = true
  zone_id = var.route53_zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60
}

# Certificate Validation
resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# HTTPS Listener
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = aws_acm_certificate.main.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }

  lifecycle {
    create_before_destroy = true
    replace_triggered_by  = [aws_acm_certificate.main]
  }

  depends_on = [aws_acm_certificate_validation.main]
}

# Note: A records for apex and www domains already exist in Route53
# and are managed outside of Terraform

# Apex domain listener rule
resource "aws_lb_listener_rule" "apex_rule" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 90  # Higher priority than staging rule

  condition {
    host_header {
      values = [var.domain_name]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

# WWW subdomain listener rule
resource "aws_lb_listener_rule" "www_rule" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 85  # Higher priority than staging rule

  condition {
    host_header {
      values = ["www.${var.domain_name}"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

# Production API subdomain listener rule
resource "aws_lb_listener_rule" "api_production_rule" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 80

  condition {
    host_header {
      values = ["api.${var.domain_name}"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

# Staging API subdomain listener rule
resource "aws_lb_listener_rule" "api_staging_rule" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 75

  condition {
    host_header {
      values = ["staging.api.${var.domain_name}"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}


