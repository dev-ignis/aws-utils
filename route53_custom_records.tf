# Custom DNS Records Management
# This file handles flexible DNS record creation based on tfvars input

# CNAME Records
resource "aws_route53_record" "cname" {
  for_each = var.skip_route53 ? {} : var.cname_records
  
  zone_id = local.zone_id
  name    = each.key == "@" ? var.hosted_zone_name : "${each.key}.${var.hosted_zone_name}"
  type    = "CNAME"
  ttl     = 300
  records = [each.value]
  allow_overwrite = true

  lifecycle {
    create_before_destroy = true
  }
}

# TXT Records
resource "aws_route53_record" "txt" {
  for_each = var.skip_route53 ? {} : var.txt_records
  
  zone_id = local.zone_id
  name    = each.key == "@" ? var.hosted_zone_name : "${each.key}.${var.hosted_zone_name}"
  type    = "TXT"
  ttl     = 300
  records = each.value
  allow_overwrite = true

  lifecycle {
    create_before_destroy = true
  }
}

# Generic Custom DNS Records (supports any record type)
resource "aws_route53_record" "custom" {
  for_each = var.skip_route53 ? {} : var.custom_dns_records
  
  zone_id = local.zone_id
  name    = each.key == "@" ? var.hosted_zone_name : "${each.key}.${var.hosted_zone_name}"
  type    = each.value.type
  ttl     = each.value.ttl
  records = each.value.records

  lifecycle {
    create_before_destroy = true
  }
}

# Output all custom DNS records for reference
output "custom_dns_records_created" {
  description = "Map of all custom DNS records created"
  value = merge(
    { for k, v in aws_route53_record.cname : k => {
      type    = "CNAME"
      name    = v.name
      records = v.records
    }},
    { for k, v in aws_route53_record.txt : k => {
      type    = "TXT"
      name    = v.name
      records = v.records
    }},
    { for k, v in aws_route53_record.custom : k => {
      type    = v.type
      name    = v.name
      records = v.records
    }}
  )
}