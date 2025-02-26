# Production API endpoint
resource "aws_route53_record" "api_production" {
  zone_id = var.route53_zone_id
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
  zone_id = var.route53_zone_id
  name    = var.staging_api_dns_name
  type    = "A"

  alias {
    name                   = aws_lb.app_lb.dns_name
    zone_id                = aws_lb.app_lb.zone_id
    evaluate_target_health = true
  }
}
