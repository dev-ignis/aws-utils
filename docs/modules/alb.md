# ALB (Application Load Balancer) Module

## Overview

The ALB module manages the Application Load Balancer infrastructure, including SSL/TLS certificate provisioning via AWS Certificate Manager (ACM), HTTPS listeners, and intelligent routing rules. This module provides secure, scalable load balancing for containerized applications with automatic SSL certificate management and zero-downtime deployment capabilities through blue-green target groups.

## Architecture

### Components Created

1. **Application Load Balancer**
   - Internet-facing load balancer
   - Deployed across multiple availability zones
   - Handles SSL/TLS termination

2. **Target Groups**
   - **Main Target Group**: HTTP protocol on port 80 for standard deployments
   - **Blue Target Group**: For blue-green deployments (zero-downtime)
   - **Green Target Group**: For blue-green deployments (zero-downtime)
   - Enhanced health checks on `/health` endpoint with optimized parameters
   - 30-second deregistration delay for graceful shutdowns

3. **SSL/TLS Certificate**
   - AWS Certificate Manager (ACM) certificate
   - Automatic DNS validation
   - Wildcard support for subdomains

4. **Listeners**
   - **HTTP Listener (Port 80)**: Redirects all traffic to HTTPS
   - **HTTPS Listener (Port 443)**: Forwards traffic to target group

5. **Listener Rules**
   - Host-based routing for apex domain
   - Staging environment routing support
   - Priority-based rule evaluation

## Module Interface

### Input Variables

| Variable | Description | Type | Required | Default |
|----------|-------------|------|----------|---------|
| `instance_name` | Name prefix for all resources | `string` | Yes | - |
| `app_port` | Application port (not actively used) | `string` | Yes | - |
| `vpc_id` | VPC ID for target group | `string` | Yes | - |
| `lb_subnet_ids` | Subnet IDs for ALB deployment | `list(string)` | Yes | - |
| `security_group_id` | Security group ID for ALB | `string` | Yes | - |
| `instance_ids` | EC2 instance IDs to attach | `list(string)` | Yes | - |
| `staging_api_dns_name` | DNS name for staging API | `string` | Yes | - |
| `domain_name` | Primary domain name | `string` | Yes | - |
| `environment` | Environment tag | `string` | Yes | - |
| `route53_zone_id` | Route53 hosted zone ID | `string` | Yes | - |
| `skip_route53` | Skip Route53 record creation | `bool` | No | `false` |

### Output Values

| Output | Description | Type |
|--------|-------------|------|
| `dns_name` | DNS name of the load balancer | `string` |
| `lb_dns_name` | Full DNS name of the load balancer | `string` |
| `lb_zone_id` | Hosted zone ID of the load balancer | `string` |
| `blue_target_group_arn` | ARN of the blue target group for blue-green deployments | `string` |
| `green_target_group_arn` | ARN of the green target group for blue-green deployments | `string` |
| `main_target_group_arn` | ARN of the main target group | `string` |
| `https_listener_arn` | ARN of the HTTPS listener for blue-green switching | `string` |

## SSL/TLS Configuration

### Certificate Details
- **Primary Domain**: Configured via `domain_name` variable
- **Subject Alternative Names**: Wildcard certificate (`*.domain.com`)
- **Validation Method**: DNS validation via Route53
- **Auto-renewal**: Managed by AWS

### SSL Policy
- Uses `ELBSecurityPolicy-TLS-1-2-2017-01`
- Supports TLS 1.2 and above
- Strong cipher suites only

## Routing Configuration

### Default Routing Behavior

1. **HTTP Traffic** (Port 80)
   - All requests redirected to HTTPS (301 redirect)
   - Preserves host, path, and query parameters

2. **HTTPS Traffic** (Port 443)
   - Default action: Forward to target group
   - Host-based routing rules applied

### Routing Rules

1. **Apex Domain Rule** (Priority 90)
   - Matches: `domain.com`
   - Action: Forward to target group

2. **Staging API Rule** (Priority 100)
   - Matches: `staging.api.domain.com`
   - Action: Forward to target group

## Health Check Configuration

Enhanced health check settings optimized for zero-downtime deployments:

- **Path**: `/health`
- **Protocol**: HTTP
- **Interval**: 15 seconds (reduced for faster detection)
- **Timeout**: 5 seconds
- **Healthy Threshold**: 2 consecutive successes (faster recovery)
- **Unhealthy Threshold**: 3 consecutive failures
- **Matcher**: HTTP 200 status code
- **Deregistration Delay**: 30 seconds (graceful shutdown)

## Usage Example

```hcl
module "alb" {
  source               = "./modules/alb"
  instance_name        = "my-app"
  app_port            = "8080"
  vpc_id              = module.network.vpc_id
  lb_subnet_ids       = module.network.lb_subnet_ids
  security_group_id   = module.network.alb_security_group_id
  instance_ids        = aws_instance.my_ec2[*].id
  staging_api_dns_name = "staging.api.example.com"
  domain_name         = "example.com"
  environment         = "production"
  route53_zone_id     = aws_route53_zone.main.zone_id
}
```

## Certificate Validation Process

1. ACM creates certificate request
2. DNS validation records are created in Route53
3. ACM validates domain ownership
4. Certificate is issued and attached to ALB
5. Auto-renewal handled by AWS

## Zero-Downtime Deployment Features

### Blue-Green Target Groups
- **Blue Target Group**: Production environment
- **Green Target Group**: Staging/new deployment environment  
- **Instant Switching**: Traffic can be switched between target groups instantly
- **Rollback Capability**: Quick rollback by switching listener back to previous target group

### Enhanced Health Checks
- **Faster Detection**: 15-second intervals detect issues quickly
- **Optimized Thresholds**: 2 healthy checks for faster service restoration
- **Graceful Shutdown**: 30-second deregistration delay allows existing connections to complete

### Deployment Strategies Supported
1. **Rolling Deployment**: Default behavior with enhanced health monitoring
2. **Blue-Green Deployment**: Complete environment switching via target group management
3. **Canary Deployment**: Partial traffic shifting (can be implemented using weighted routing)

## Important Considerations

### High Availability
- ALB automatically distributes traffic across healthy instances
- Multi-AZ deployment ensures availability
- Enhanced health checks remove unhealthy targets quickly
- Blue-green target groups provide instant failover capability

### Security
- All HTTP traffic forced to HTTPS
- Strong TLS policy enforced
- Certificate validation prevents unauthorized use

### Performance
- Connection draining enabled with optimized 30-second delay
- Keep-alive connections supported
- HTTP/2 enabled by default
- Faster health check detection (15s vs 30s)

### Cost Factors
- ALB hourly charges
- Data processing charges
- Additional target groups for blue-green (minimal cost impact)
- ACM certificates are free
- Route53 hosted zone queries

## Lifecycle Management

- Resources use `create_before_destroy` to prevent downtime
- Certificate changes trigger listener updates
- Proper dependency management with `depends_on`

## Troubleshooting

### Common Issues

1. **Certificate Validation Failure**
   - Verify Route53 zone ownership
   - Check DNS propagation
   - Ensure validation records exist

2. **Unhealthy Targets**
   - Verify `/health` endpoint responds with 200 OK
   - Check security group rules
   - Review application logs

3. **SSL Certificate Errors**
   - Confirm certificate covers requested domain
   - Check certificate is validated
   - Verify listener configuration

### Debug Commands

```bash
# Check ALB status
aws elbv2 describe-load-balancers --names my-app-lb

# View target health
aws elbv2 describe-target-health --target-group-arn arn:aws:elasticloadbalancing:...

# Check certificate status
aws acm describe-certificate --certificate-arn arn:aws:acm:...

# View listener rules
aws elbv2 describe-rules --listener-arn arn:aws:elasticloadbalancing:...
```

## Best Practices

1. **Health Check Optimization**
   - Implement lightweight health endpoint
   - Return quickly (< 5 seconds)
   - Include dependency checks

2. **SSL/TLS Security**
   - Regularly review SSL policies
   - Monitor for deprecated ciphers
   - Consider implementing HSTS headers

3. **Routing Strategy**
   - Use priority values with gaps (10, 20, 30)
   - Document routing logic
   - Test with various host headers

4. **Monitoring**
   - Enable ALB access logs
   - Set up CloudWatch alarms
   - Monitor certificate expiration

## Limitations

- Fixed to HTTP/HTTPS protocols
- No WebSocket support in current configuration
- Single certificate per ALB
- No path-based routing implemented

## Related Documentation

- [AWS ALB Documentation](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/)
- [ACM User Guide](https://docs.aws.amazon.com/acm/latest/userguide/)
- [ALB Listener Rules](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/listener-update-rules.html)