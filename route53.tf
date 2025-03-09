# Conditionally create a hosted zone if required
resource "aws_route53_zone" "this" {
  count = var.create_hosted_zone ? 1 : 0
  name  = var.hosted_zone_name
}

# Use the created zone's ID if we created one; otherwise, use the provided zone id.
locals {
  zone_id = var.create_hosted_zone ? aws_route53_zone.this[0].id : var.route53_zone_id
}

# EC2 instance DNS record (if applicable)
resource "aws_route53_record" "ec2_dns" {
  count   = var.dns_name != "" ? 1 : 0
  zone_id = local.zone_id
  name    = var.dns_name
  type    = "A"
  ttl     = 300
  records = [aws_instance.my_ec2[0].public_ip]
}

# Production API endpoint
resource "aws_route53_record" "api_production" {
  zone_id = local.zone_id
  name    = "api.amygdalas.com"
  type    = "A"

  alias {
    name                   = module.alb[0].lb_dns_name
    zone_id                = module.alb[0].lb_zone_id
    evaluate_target_health = true
  }
}

# Staging API endpoint using the variable
resource "aws_route53_record" "api_staging" {
  zone_id = local.zone_id
  name    = var.staging_api_dns_name
  type    = "A"

  alias {
    name                   = module.alb[0].lb_dns_name
    zone_id                = module.alb[0].lb_zone_id
    evaluate_target_health = true
  }
}
