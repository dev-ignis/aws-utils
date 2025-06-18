# Network Module

## Overview

The Network module creates the foundational networking infrastructure for the AWS Docker deployment. It establishes a Virtual Private Cloud (VPC) with public subnets across multiple availability zones, security groups for both the Application Load Balancer and EC2 instances, and all necessary routing components.

## Architecture

### Components Created

1. **VPC (Virtual Private Cloud)**
   - Custom CIDR block
   - DNS support and DNS hostnames enabled
   - Isolated network environment for all resources

2. **Subnets**
   - Two public subnets in different availability zones
   - Auto-assign public IP enabled for instances
   - Used for both EC2 instances and ALB deployment

3. **Internet Gateway**
   - Provides internet connectivity for public subnets
   - Enables inbound and outbound internet traffic

4. **Route Table**
   - Routes all internet traffic (0.0.0.0/0) through the Internet Gateway
   - Associated with both public subnets

5. **Security Groups**
   - **ALB Security Group**: Controls traffic to/from the Application Load Balancer
   - **Instance Security Group**: Controls traffic to/from EC2 instances

## Module Interface

### Input Variables

| Variable | Description | Type | Required | Default |
|----------|-------------|------|----------|---------|
| `instance_name` | Name prefix for all resources | `string` | Yes | - |
| `vpc_cidr` | CIDR block for the VPC | `string` | Yes | - |
| `subnet_cidrs` | List of CIDR blocks for subnets (minimum 2) | `list(string)` | Yes | - |
| `availability_zones` | List of AZs for subnet deployment (minimum 2) | `list(string)` | Yes | - |
| `backend_port` | Port number for backend application | `string` | Yes | - |

### Output Values

| Output | Description | Type |
|--------|-------------|------|
| `vpc_id` | ID of the created VPC | `string` |
| `instance_subnet_id` | ID of the first subnet (for single instance deployments) | `string` |
| `lb_subnet_ids` | List of subnet IDs for load balancer deployment | `list(string)` |
| `instance_security_group_id` | ID of the EC2 instance security group | `string` |
| `alb_security_group_id` | ID of the ALB security group | `string` |

## Security Group Rules

### ALB Security Group

**Ingress Rules:**
- Port 80 (HTTP) from 0.0.0.0/0
- Port 443 (HTTPS) from 0.0.0.0/0

**Egress Rules:**
- All traffic to 0.0.0.0/0 and ::/0

### Instance Security Group

**Ingress Rules:**
- Port 80 (HTTP) from ALB security group only
- Port 22 (SSH) from 0.0.0.0/0 (consider restricting in production)
- Backend application port from ALB security group only

**Egress Rules:**
- All traffic to 0.0.0.0/0

## Usage Example

```hcl
module "network" {
  source             = "./modules/network"
  instance_name      = "my-app"
  vpc_cidr           = "10.0.0.0/16"
  subnet_cidrs       = ["10.0.1.0/24", "10.0.2.0/24"]
  availability_zones = ["us-west-2a", "us-west-2b"]
  backend_port       = "8080"
}
```

## Important Considerations

### High Availability
- The module creates resources across two availability zones by default
- This ensures resilience against AZ failures
- Both subnets are public, suitable for ALB deployment

### Security
- The instance security group only allows traffic from the ALB
- SSH access is open to the internet by default - restrict this in production
- Consider implementing Network ACLs for additional security layers

### Cost Optimization
- Public subnets don't incur NAT Gateway charges
- Internet Gateway is free but data transfer charges apply
- Consider private subnets with NAT Gateway for enhanced security (additional cost)

### Limitations
- Currently only supports public subnets
- Fixed to two availability zones
- No support for IPv6 (though egress rules allow it)

## Resource Dependencies

The module creates resources with proper lifecycle management:
- Security groups use `create_before_destroy` to prevent disruption
- Instance security group has a replace trigger on ALB security group changes
- All resources are properly tagged for identification

## Troubleshooting

### Common Issues

1. **CIDR Block Conflicts**
   - Ensure VPC CIDR doesn't overlap with existing VPCs
   - Subnet CIDRs must be within VPC CIDR range

2. **Availability Zone Errors**
   - Verify the specified AZs exist in your region
   - Some AZs may not support certain instance types

3. **Security Group Rule Conflicts**
   - Check for duplicate rule definitions
   - Ensure port numbers are valid (1-65535)

### Debug Commands

```bash
# List VPCs
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=*my-app*"

# Check subnet configuration
aws ec2 describe-subnets --filters "Name=vpc-id,Values=vpc-xxxxx"

# Review security group rules
aws ec2 describe-security-groups --group-ids sg-xxxxx
```

## Best Practices

1. **CIDR Planning**
   - Use non-overlapping CIDR blocks
   - Reserve IP ranges for future expansion
   - Follow RFC 1918 for private IP addressing

2. **Tagging Strategy**
   - All resources are tagged with instance_name
   - Consider adding environment and cost center tags

3. **Security Hardening**
   - Restrict SSH access to known IP ranges
   - Implement VPC Flow Logs for monitoring
   - Consider AWS WAF for the ALB

## Related Documentation

- [AWS VPC Documentation](https://docs.aws.amazon.com/vpc/)
- [Security Group Best Practices](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_SecurityGroups.html)
- [Subnet Sizing](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Subnets.html#vpc-subnet-basics)