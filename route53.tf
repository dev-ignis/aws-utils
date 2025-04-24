# Conditionally create a hosted zone if required and if not skipped.
resource "aws_route53_zone" "this" {
  count = var.create_hosted_zone && !var.skip_route53 ? 1 : 0
  name  = var.hosted_zone_name
  
  # Add tags for better management
  tags = {
    Name        = "${var.hosted_zone_name}"
    Environment = var.environment
    Terraform   = "true"
  }
}

# Use the created zone's ID if we created one; otherwise, use the provided zone id.
locals {
  zone_id = var.create_hosted_zone && !var.skip_route53 ? aws_route53_zone.this[0].id : var.route53_zone_id
}

# EC2 instance DNS record (only create if dns_name is set and skip_route53 is false)
resource "aws_route53_record" "ec2_dns" {
  count   = (var.skip_route53 || var.dns_name == "") ? 0 : 1
  zone_id = local.zone_id
  name    = var.dns_name
  type    = "A"
  ttl     = 300
  records = [aws_instance.my_ec2[0].public_ip]
}

# Production API endpoint (skipped in CI if skip_route53 is true)
resource "aws_route53_record" "api_production" {
  count = var.skip_route53 ? 0 : 1
  zone_id = local.zone_id
  name    = var.prod_api_dns_name
  type    = "A"

  alias {
    name                   = module.alb[0].lb_dns_name
    zone_id                = module.alb[0].lb_zone_id
    evaluate_target_health = true
  }
}

# Staging API endpoint (skipped in CI if skip_route53 is true)
resource "aws_route53_record" "api_staging" {
  count = var.skip_route53 ? 0 : 1
  zone_id = local.zone_id
  name    = var.staging_api_dns_name
  type    = "A"

  alias {
    name                   = module.alb[0].lb_dns_name
    zone_id                = module.alb[0].lb_zone_id
    evaluate_target_health = true
  }
}

# WWW subdomain record - points to the same ALB
resource "aws_route53_record" "www" {
  count   = var.skip_route53 ? 0 : 1
  zone_id = local.zone_id
  name    = "www.${var.hosted_zone_name}"
  type    = "A"
  
  alias {
    name                   = module.alb[0].lb_dns_name
    zone_id                = module.alb[0].lb_zone_id
    evaluate_target_health = true
  }
}

# Root domain record - if not already covered by other records
resource "aws_route53_record" "apex" {
  count   = var.skip_route53 ? 0 : (var.create_apex_record ? 1 : 0)
  zone_id = local.zone_id
  name    = var.hosted_zone_name
  type    = "A"
  
  alias {
    name                   = module.alb[0].lb_dns_name
    zone_id                = module.alb[0].lb_zone_id
    evaluate_target_health = true
  }
}

# MX records for email
resource "aws_route53_record" "mx" {
  count   = var.skip_route53 ? 0 : (var.create_mail_records ? 1 : 0)
  zone_id = local.zone_id
  name    = var.hosted_zone_name
  type    = "MX"
  ttl     = 300
  records = var.mx_records
}

# SPF record for email verification
resource "aws_route53_record" "spf" {
  count   = var.skip_route53 ? 0 : (var.create_mail_records ? 1 : 0)
  zone_id = local.zone_id
  name    = var.hosted_zone_name
  type    = "TXT"
  ttl     = 300
  records = ["v=spf1 ${var.spf_record} -all"]
}

# DKIM record for email verification
resource "aws_route53_record" "dkim" {
  count   = var.skip_route53 ? 0 : (var.create_mail_records && length(var.dkim_records) > 0 ? 1 : 0)
  zone_id = local.zone_id
  name    = "${var.dkim_selector}._domainkey.${var.hosted_zone_name}"
  type    = "TXT"
  ttl     = 300
  records = var.dkim_records
}

# DMARC record for email verification
resource "aws_route53_record" "dmarc" {
  count   = var.skip_route53 ? 0 : (var.create_mail_records ? 1 : 0)
  zone_id = local.zone_id
  name    = "_dmarc.${var.hosted_zone_name}"
  type    = "TXT"
  ttl     = 300
  records = ["v=DMARC1; p=${var.dmarc_policy}; rua=mailto:${var.dmarc_email}"]
}

# Optional wildcard record to catch any undefined subdomains
resource "aws_route53_record" "wildcard" {
  count   = var.skip_route53 ? 0 : (var.create_wildcard_record ? 1 : 0)
  zone_id = local.zone_id
  name    = "*.${var.hosted_zone_name}"
  type    = "A"
  
  alias {
    name                   = module.alb[0].lb_dns_name
    zone_id                = module.alb[0].lb_zone_id
    evaluate_target_health = true
  }
}
