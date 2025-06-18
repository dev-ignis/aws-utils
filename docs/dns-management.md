# DNS Record Management

## Overview

This infrastructure now supports flexible DNS record management through Terraform variables, allowing you to create and manage CNAME, TXT, and other DNS record types directly from your `terraform.tfvars` file. This eliminates the need to modify Terraform code when adding or updating DNS records.

## Features

- **CNAME Records**: Easy subdomain aliasing to external services
- **TXT Records**: Support for verification, SPF, DKIM, and other text records
- **Custom Records**: Flexible support for any DNS record type (A, AAAA, MX, SRV, CAA, etc.)
- **Declarative Configuration**: Define all records in your tfvars file
- **Automatic Naming**: Subdomain handling with support for root domain (@) notation

## Configuration Methods

### Method 1: Simple CNAME Records

Use the `cname_records` variable for straightforward CNAME configurations:

```hcl
cname_records = {
  "blog"     = "myblog.wordpress.com."
  "shop"     = "myshop.shopify.com."
  "support"  = "support.zendesk.com."
}
```

This creates:
- `blog.example.com` → `myblog.wordpress.com.`
- `shop.example.com` → `myshop.shopify.com.`
- `support.example.com` → `support.zendesk.com.`

### Method 2: TXT Records

Use the `txt_records` variable for TXT record management:

```hcl
txt_records = {
  "@" = [
    "google-site-verification=abc123def456",
    "v=spf1 include:_spf.google.com ~all"
  ]
  "_dmarc" = ["v=DMARC1; p=quarantine; rua=mailto:dmarc@example.com"]
  "mail._domainkey" = ["v=DKIM1; k=rsa; p=MIGfMA0..."]
}
```

**Note**: Use `"@"` as the key to create records at the root domain.

### Method 3: Advanced Custom Records

For complete control, use the `custom_dns_records` variable:

```hcl
custom_dns_records = {
  "subdomain" = {
    type    = "A"
    ttl     = 3600
    records = ["192.168.1.100"]
  }
  "_sip._tcp" = {
    type    = "SRV"
    ttl     = 3600
    records = ["10 60 5060 sip.example.com."]
  }
}
```

## Common Use Cases

### 1. Email Service Configuration

```hcl
# Google Workspace
cname_records = {
  "mail"     = "ghs.googlehosted.com."
  "calendar" = "ghs.googlehosted.com."
  "drive"    = "ghs.googlehosted.com."
}

txt_records = {
  "@" = [
    "v=spf1 include:_spf.google.com ~all",
    "google-site-verification=your-verification-code"
  ]
}
```

### 2. Third-Party Service Verification

```hcl
txt_records = {
  "@" = [
    "google-site-verification=abc123",
    "facebook-domain-verification=xyz789",
    "stripe-verification=def456"
  ]
  "_github-challenge" = ["verification-code-here"]
}
```

### 3. CDN and Static Site Hosting

```hcl
cname_records = {
  "www"    = "d111111abcdef8.cloudfront.net."
  "assets" = "d222222abcdef8.cloudfront.net."
  "images" = "mybucket.s3-website-us-east-1.amazonaws.com."
}
```

### 4. Subdomain Delegation

```hcl
custom_dns_records = {
  "subdomain" = {
    type    = "NS"
    ttl     = 172800
    records = [
      "ns1.other-provider.com.",
      "ns2.other-provider.com."
    ]
  }
}
```

### 5. SSL Certificate Validation

```hcl
txt_records = {
  "_acme-challenge" = ["validation-string-from-ca"]
  "_acme-challenge.www" = ["another-validation-string"]
}

# Or for CAA records
custom_dns_records = {
  "@" = {
    type    = "CAA"
    ttl     = 3600
    records = [
      "0 issue \"letsencrypt.org\"",
      "0 issuewild \"letsencrypt.org\""
    ]
  }
}
```

## Variable Reference

### `cname_records`
- **Type**: `map(string)`
- **Default**: `{}`
- **Description**: Simple CNAME record mapping. Key is subdomain, value is target.

### `txt_records`
- **Type**: `map(list(string))`
- **Default**: `{}`
- **Description**: TXT record mapping. Key is subdomain (@ for root), value is list of TXT strings.

### `custom_dns_records`
- **Type**: `map(object({type=string, ttl=number, records=list(string)}))`
- **Default**: `{}`
- **Description**: Flexible DNS record creation supporting any record type.

## Important Notes

### DNS Record Format
- Always include trailing dots (.) for fully qualified domain names in record values
- The module automatically handles subdomain prefixing with your `hosted_zone_name`
- Use `"@"` as the key for root domain records

### TTL (Time To Live)
- Default TTL for CNAME and TXT records: 300 seconds (5 minutes)
- Custom records allow you to specify any TTL value
- Lower TTL = faster propagation but more DNS queries
- Higher TTL = better caching but slower updates

### Record Limits
- TXT records: 255 characters per string (use multiple strings if needed)
- CNAME records: Cannot be created at the root domain
- Total records: AWS Route53 supports up to 10,000 records per hosted zone

### Best Practices
1. **Always validate DNS records** after applying changes
2. **Use lower TTLs** when testing or making frequent changes
3. **Document the purpose** of each record in comments
4. **Group related records** together in your tfvars file
5. **Regular audits** to remove unused DNS records

## Validation Commands

After applying DNS changes, validate them:

```bash
# Check CNAME records
dig CNAME blog.example.com +short

# Check TXT records
dig TXT example.com +short

# Check specific record type
dig A subdomain.example.com +short

# Check all records for a domain
dig ANY example.com

# Use AWS CLI to list records
aws route53 list-resource-record-sets --hosted-zone-id Z1234567890ABC
```

## Troubleshooting

### Records Not Creating
1. Check `skip_route53` variable is not set to `true`
2. Verify `route53_zone_id` is correct
3. Ensure you have proper AWS permissions

### DNS Not Resolving
1. Wait for TTL to expire (5-10 minutes for new records)
2. Clear local DNS cache
3. Check record format (trailing dots for FQDNs)

### Terraform Errors
1. Validate record values don't exceed limits
2. Ensure no duplicate record definitions
3. Check for conflicting record types at same name

## Migration Guide

If you have existing hardcoded DNS records in `route53.tf`:

1. Identify all hardcoded records
2. Move them to your `terraform.tfvars` using appropriate variables
3. Run `terraform plan` to verify no changes
4. Remove hardcoded resources from `route53.tf`
5. Run `terraform apply`

## Example Complete Configuration

```hcl
# Production environment with full DNS setup
hosted_zone_name = "example.com"
route53_zone_id  = "Z1234567890ABC"

# Standard service CNAMEs
cname_records = {
  "www"      = "example.com."
  "blog"     = "myblog.medium.com."
  "shop"     = "myshop.shopify.com."
  "status"   = "stats.uptimerobot.com."
  "calendar" = "cal.calendly.com."
}

# Verification and security TXT records
txt_records = {
  "@" = [
    "v=spf1 include:_spf.google.com include:amazonses.com ~all",
    "google-site-verification=abc123def456",
    "stripe-verification=xyz789"
  ]
  "_dmarc" = ["v=DMARC1; p=quarantine; rua=mailto:dmarc@example.com"]
  "_domainkey" = ["t=y; o=~;"]
}

# Advanced custom records
custom_dns_records = {
  # Load balancing with multiple IPs
  "lb" = {
    type    = "A"
    ttl     = 60
    records = ["10.0.1.10", "10.0.1.11", "10.0.1.12"]
  }
  
  # Certificate authority authorization
  "@" = {
    type    = "CAA"
    ttl     = 3600
    records = ["0 issue \"letsencrypt.org\""]
  }
}
```