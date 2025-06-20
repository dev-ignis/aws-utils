# Zero-Downtime Deployment Guide

## Overview

This infrastructure supports multiple deployment strategies to ensure zero downtime during application updates. This guide covers both rolling deployments and blue-green deployments, their use cases, and implementation details.

## Deployment Strategies

### 1. Rolling Deployment (Default)

Rolling deployment updates instances sequentially while maintaining service availability through the Application Load Balancer.

#### How It Works

1. **Sequential Updates**: Instances are updated one at a time
2. **Health Validation**: Each instance must pass health checks before proceeding
3. **Traffic Management**: ALB routes traffic only to healthy instances
4. **Graceful Switching**: Nginx configuration is updated to route to new containers

#### Implementation Details

**Backend Rolling Deployment (`redeploy_app.tf`):**
- Starts new container on temporary port (original_port + 1000)
- Validates health check on `/health` endpoint (12 attempts, 5-second intervals)
- Updates Nginx configuration to route traffic to new container
- Stops old container and starts new one on original port
- Restores Nginx configuration

**Frontend Rolling Deployment (`redeploy_front_end.tf`):**
- Similar process but checks root endpoint `/` for health
- Longer initial wait time (20 seconds) for frontend startup

#### Usage

```bash
# Update backend
terraform apply -var="backend_image=myapp/backend:v2.0"

# Update frontend
terraform apply -var="front_end_image=myapp/frontend:v2.0"

# Update both simultaneously
terraform apply -var="backend_image=myapp/backend:v2.0" -var="front_end_image=myapp/frontend:v2.0"
```

#### Advantages
- **Simple**: Uses existing infrastructure
- **Resource Efficient**: No additional instances required
- **Gradual**: Issues are contained to single instances

#### Disadvantages
- **Slower**: Sequential updates take longer
- **Risk**: If health checks fail, deployment stops
- **Complexity**: Requires container port management

### 2. Blue-Green Deployment

Blue-green deployment creates a complete duplicate environment and switches traffic instantly.

#### How It Works

1. **Dual Environments**: Blue (current) and Green (new) target groups
2. **Parallel Deployment**: New version deployed to inactive target group
3. **Health Validation**: All instances in inactive target group must be healthy
4. **Instant Switch**: ALB listener updated to point to new target group
5. **Rollback Ready**: Previous environment remains available for instant rollback

#### Implementation Details

**Target Group Management:**
- **Blue Target Group**: `${instance_name}-blue-tg`
- **Green Target Group**: `${instance_name}-green-tg`
- **Enhanced Health Checks**: 15-second intervals, 5-second timeout
- **Graceful Deregistration**: 30-second delay for connection draining

**Deployment Process (`blue_green_deploy.tf`):**
1. Deploy applications to all instances
2. Register instances with inactive target group
3. Wait 60 seconds for health check stabilization
4. Validate all targets are healthy
5. Update HTTPS listener to point to inactive target group
6. Deregister instances from old active target group

#### Usage

```bash
# Initial blue-green deployment (assumes blue is active)
terraform apply -var="blue_green_enabled=true" -var="backend_image=myapp/backend:v2.0"

# After successful deployment, update the active target group variable
terraform apply -var="blue_green_enabled=true" -var="active_target_group=green"

# Next deployment (green is now active, deploying to blue)
terraform apply -var="blue_green_enabled=true" -var="backend_image=myapp/backend:v3.0"
terraform apply -var="blue_green_enabled=true" -var="active_target_group=blue"
```

#### Advantages
- **Instant Switching**: Zero-downtime traffic cutover
- **Full Rollback**: Complete previous environment available
- **Testing**: New environment can be tested before switching
- **Clean State**: Each deployment starts with fresh environment

#### Disadvantages
- **Resource Usage**: Requires additional ALB target groups
- **Complexity**: More moving parts and state management
- **Manual Step**: Requires updating `active_target_group` variable

## Deployment Validation and Rollback

### Automatic Validation (`rollback_deploy.tf`)

The infrastructure includes comprehensive validation and monitoring:

#### Validation Process
1. **Health Check Monitoring**: Continuous monitoring of target group health
2. **Timeout-based Validation**: Configurable timeout (default 5 minutes)
3. **Automatic Rollback**: Triggers on health check failures
4. **Extended Monitoring**: 10-minute post-deployment monitoring

#### Rollback Mechanisms

**Blue-Green Rollback:**
- **Instant**: Switch ALB listener back to previous target group
- **Automatic**: Triggered by health check failures
- **Manual**: Can be triggered by changing `active_target_group` variable

**Rolling Deployment Rollback:**
- **Manual Intervention**: Requires redeployment with previous image
- **Health Check Protection**: Failed deployments don't proceed to next instance

### Configuration Variables

```hcl
# Enable/disable automatic rollback
enable_rollback = true

# Time to wait before considering deployment failed
rollback_timeout_minutes = 5

# Blue-green deployment settings
blue_green_enabled = true
active_target_group = "blue"  # or "green"
```

## Best Practices

### Health Check Endpoint

Ensure your application implements a robust health check endpoint:

```javascript
// Example Node.js health check
app.get('/health', (req, res) => {
  // Check database connectivity
  // Check external dependencies
  // Return 200 OK only if all systems are healthy
  res.status(200).json({ status: 'healthy', timestamp: new Date().toISOString() });
});
```

### Deployment Strategy Selection

**Use Rolling Deployment When:**
- Resource constraints are important
- Simple deployment process is preferred
- Application can handle brief per-instance downtime
- Cost optimization is a priority

**Use Blue-Green Deployment When:**
- Zero downtime is critical
- Instant rollback capability is required
- You need to test new deployments before switching traffic
- Application state can handle environment switching

### Monitoring and Observability

1. **CloudWatch Alarms**: Set up alarms for ALB target health
2. **Application Metrics**: Monitor application-specific metrics during deployments
3. **Log Monitoring**: Watch for errors during deployment windows
4. **Performance Testing**: Validate performance after deployments

### Pre-Deployment Checklist

- [ ] Health check endpoint returns 200 OK
- [ ] New Docker images are accessible
- [ ] Database migrations (if any) are backward compatible
- [ ] Monitoring dashboards are ready
- [ ] Rollback plan is documented
- [ ] Deployment window is scheduled during low traffic

### Post-Deployment Verification

1. **Health Checks**: Verify all targets are healthy in ALB console
2. **Application Testing**: Test critical user journeys
3. **Performance Monitoring**: Check response times and error rates
4. **Log Review**: Look for any errors or warnings
5. **Monitoring**: Observe metrics for 10+ minutes after deployment

## Troubleshooting

### Common Issues

#### Rolling Deployment Failures

**Symptom**: Health check fails during rolling deployment
**Causes**:
- Application startup time longer than health check timeout
- Missing environment variables
- Port conflicts
- Resource constraints

**Solutions**:
```bash
# Check container logs
ssh ubuntu@instance-ip
docker logs container-name

# Verify health check endpoint
curl http://localhost:8080/health

# Check resource usage
docker stats
```

#### Blue-Green Deployment Issues

**Symptom**: Target group shows unhealthy targets
**Causes**:
- Insufficient warm-up time
- Application configuration issues
- Load balancer health check configuration

**Solutions**:
```bash
# Check target group health
aws elbv2 describe-target-health --target-group-arn arn:aws:elasticloadbalancing:...

# Manually test health endpoint
curl http://instance-ip/health

# Review ALB access logs (if enabled)
aws s3 cp s3://alb-logs-bucket/... -
```

#### Rollback Scenarios

**Automatic Rollback Triggered**:
1. Check deployment logs for failure reasons
2. Verify health check endpoint functionality
3. Review application logs for startup errors
4. Consider extending `rollback_timeout_minutes` if needed

**Manual Rollback Required**:
```bash
# Blue-green rollback
terraform apply -var="blue_green_enabled=true" -var="active_target_group=previous_color"

# Rolling deployment rollback
terraform apply -var="backend_image=previous_version"
```

## Monitoring Commands

```bash
# Check ALB target health
aws elbv2 describe-target-health --target-group-arn <target-group-arn>

# Monitor deployment progress
aws elbv2 describe-target-health --target-group-arn <target-group-arn> --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State]' --output table

# View ALB listener configuration
aws elbv2 describe-listeners --load-balancer-arn <alb-arn>

# Check container status on instances
ssh ubuntu@instance-ip "docker ps"
```

## Advanced Configurations

### Custom Health Check Configuration

Modify the ALB module health check settings in `modules/alb/main.tf`:

```hcl
health_check {
  path                = "/health"
  protocol            = "HTTP"
  interval            = 15    # Adjust based on your needs
  timeout             = 5     # Adjust based on your application
  healthy_threshold   = 2     # Faster recovery
  unhealthy_threshold = 3     # Stability vs speed trade-off
  matcher             = "200"
}
```

### External Validation and Discord Notifications

To optimize deployment time while maintaining thorough validation, the infrastructure supports external validation with Discord notifications.

#### Fast Deployment Mode

Enable fast deployment mode to reduce Terraform apply time from 15+ minutes to ~1 minute:

```bash
# terraform.tfvars
skip_deployment_validation = true
enable_discord_notifications = true
discord_webhook_url = "https://discord.com/api/webhooks/YOUR_WEBHOOK_URL"
```

#### External Validation Script

After a fast Terraform deployment, run comprehensive validation externally:

```bash
# Run external validation with Discord notifications
./scripts/post-deploy-validate.sh
```

**The script provides:**
- **5-minute validation phase** with health checks and endpoint testing
- **10-minute extended monitoring** running in background
- **Automatic rollback** on validation failure
- **Discord notifications** with rich embeds and deployment status
- **Comprehensive logging** for troubleshooting

#### Discord Integration Features

**Rich Notifications:**
- Deployment start/completion status
- Validation progress and results
- Health check status and target group information
- Automatic rollback notifications
- Extended monitoring alerts

**Configuration:**
```bash
# Enable Discord notifications
enable_discord_notifications = true
discord_webhook_url = "https://discord.com/api/webhooks/YOUR_WEBHOOK_URL"

# Fast deployment mode
skip_deployment_validation = true
```

#### Usage Workflow

1. **Fast Deploy**: Run Terraform with validation skipped (~1 minute)
2. **External Validation**: Script validates deployment (~5 minutes)
3. **Background Monitoring**: Extended monitoring continues (~10 minutes)
4. **Discord Updates**: Real-time notifications throughout process

```bash
# Fast deployment
terraform apply -var="backend_image=myapp:v2.0"

# External validation (automatically triggered or manual)
./scripts/post-deploy-validate.sh

# Monitor via Discord notifications or logs
tail -f logs/validation-$(date +%Y-%m-%d)*.log
```

### Weighted Routing (Canary Deployments)

For advanced canary deployments, consider implementing weighted target groups:

```hcl
# Example: 90% traffic to blue, 10% to green
action {
  type = "forward"
  forward {
    target_group {
      arn    = aws_lb_target_group.blue_tg.arn
      weight = 90
    }
    target_group {
      arn    = aws_lb_target_group.green_tg.arn
      weight = 10
    }
  }
}
```

## Related Documentation

- [ALB Module Documentation](modules/alb.md)
- [Network Module Documentation](modules/network.md)
- [AWS ALB User Guide](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)