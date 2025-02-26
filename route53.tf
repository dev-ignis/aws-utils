resource "aws_route53_zone" "this" {
  count = var.create_hosted_zone ? 1 : 0
  name  = var.hosted_zone_name
}

locals {
  zone_id = var.create_hosted_zone ? aws_route53_zone.this[0].id : var.route53_zone_id
}

# Production API endpoint
resource "aws_route53_record" "api_production" {
  zone_id = local.zone_id
  name    = var.prod_api_dns_name
  type    = "A"

  alias {
    name                   = aws_lb.app_lb.dns_name
    zone_id                = aws_lb.app_lb.zone_id
    evaluate_target_health = true
  }
}

# Staging API endpoint using the variable
resource "aws_route53_record" "api_staging" {
  zone_id = local.zone_id
  name    = var.staging_api_dns_name
  type    = "A"

  alias {
    name                   = aws_lb.app_lb.dns_name
    zone_id                = aws_lb.app_lb.zone_id
    evaluate_target_health = true
  }
}
