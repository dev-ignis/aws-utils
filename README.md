# AWS Docker Deployment Infrastructure

A comprehensive Terraform-based infrastructure solution for deploying containerized applications on AWS with high availability, load balancing, and auto-scaling capabilities.

## Overview

This project provides a production-ready infrastructure setup for deploying Docker-based applications on AWS. It implements infrastructure as code (IaC) principles using Terraform modules, ensuring consistent, repeatable, and scalable deployments.

### Key Features

- **High Availability**: Multi-AZ deployment with Application Load Balancer
- **Zero-Downtime Deployments**: Rolling updates and blue-green deployment strategies
- **Container-Ready**: Automated Docker deployment for backend and frontend services
- **SSL/TLS Security**: Managed SSL certificates via AWS Certificate Manager
- **Database Integration**: DynamoDB table provisioning for application data
- **DNS Management**: Route53 integration for custom domain support
- **Modular Design**: Reusable Terraform modules for network, ALB, and database components
- **Auto-Configuration**: User data scripts for automated instance setup
- **Health Monitoring**: Comprehensive health checks with automatic rollback

## Architecture

### Components

1. **Networking Layer** - [📖 Detailed Documentation](docs/modules/network.md)
   - Custom VPC with DNS support enabled
   - Public subnets across multiple availability zones
   - Internet Gateway for public internet access
   - Security groups with controlled ingress/egress rules

2. **Compute Layer**
   - EC2 instances (2 by default) distributed across AZs
   - Docker runtime with automated container deployment
   - NGINX reverse proxy for request routing
   - Support for both backend and frontend containers

3. **Load Balancing** - [📖 Detailed Documentation](docs/modules/alb.md)
   - Application Load Balancer (ALB) for traffic distribution
   - SSL/TLS termination at ALB level
   - Enhanced health checks for automatic instance monitoring
   - Blue-green target groups for zero-downtime deployments
   - Target group with configurable routing rules

4. **Data Layer** - [📖 Detailed Documentation](docs/modules/dynamodb.md)
   - DynamoDB table with pay-per-request billing
   - Configurable hash key for flexible data modeling

5. **DNS & SSL** - [📖 DNS Management Guide](docs/dns-management.md)
   - Route53 hosted zone integration
   - AWS Certificate Manager for SSL certificates
   - Support for apex domain and subdomains
   - Flexible DNS record management (CNAME, TXT, A, etc.)

### Traffic Flow

```
Internet → Route53 → ALB (SSL Termination) → Target Group → EC2 Instances → Docker Containers
                                                                    ↓
                                                               NGINX Proxy
                                                                    ↓
                                                    Backend (API) / Frontend Services
```

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) 0.12 or higher
- AWS CLI configured with appropriate credentials
- AWS account with permissions for:
  - EC2, VPC, ALB, Route53, DynamoDB, ACM
  - IAM roles and policies
- An existing AWS key pair for SSH access
- Docker images accessible from Docker Hub or ECR
- Domain name (optional, for custom DNS)

## Project Structure

```
aws-docker-deployment/
├── main.tf                    # Main Terraform configuration
├── variables.tf               # Input variables definition
├── outputs.tf                 # Output values
├── backend.tf                 # Terraform state backend configuration
├── route53.tf                 # DNS configuration
├── copy_cert.tf              # Certificate management
├── copy_env.tf               # Environment variables handling
├── redeploy_app.tf           # Application redeployment scripts (rolling)
├── redeploy_front_end.tf     # Frontend-specific redeployment (rolling)
├── blue_green_deploy.tf      # Blue-green deployment strategy
├── rollback_deploy.tf        # Deployment validation and rollback
├── user_data.sh.tpl          # EC2 initialization script template
├── update_nginx.sh           # NGINX configuration updates
└── modules/
    ├── alb/                  # Application Load Balancer module
    │   ├── main.tf
    │   ├── ssl.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── network/              # VPC and networking module
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── dynamodb/             # DynamoDB table module
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

## Terraform Modules

This project uses a modular approach with three main Terraform modules:

### Network Module
The [Network module](docs/modules/network.md) creates the foundational AWS networking infrastructure including VPC, subnets, internet gateway, route tables, and security groups. It provides a secure, scalable network foundation for the application.

### ALB Module  
The [ALB module](docs/modules/alb.md) manages the Application Load Balancer, SSL/TLS certificates via AWS Certificate Manager, HTTPS listeners, and routing rules. It handles all aspects of load balancing and SSL termination.

### DynamoDB Module
The [DynamoDB module](docs/modules/dynamodb.md) provisions a NoSQL database table with global secondary indexes for user authentication and profile management. It's configured for on-demand billing and includes indexes for email and Apple ID lookups.

Each module is fully documented with:
- Architecture overview and components
- Input/output specifications  
- Usage examples
- Best practices
- Troubleshooting guides

## Configuration

### Required Variables

| Variable | Description | Type | Example |
|----------|-------------|------|---------|
| `region` | AWS region for deployment | string | `us-west-2` |
| `ami` | AMI ID for EC2 instances | string | `ami-0c55b159cbfafe1f0` |
| `instance_type` | EC2 instance type | string | `t2.micro` |
| `instance_name` | Name prefix for resources | string | `my-app` |
| `key_name` | AWS key pair name | string | `my-keypair` |
| `backend_image` | Docker image for backend | string | `myapp/backend:latest` |
| `backend_port` | Backend service port | number | `8080` |
| `vpc_cidr` | CIDR block for VPC | string | `10.0.0.0/16` |
| `subnet_cidrs` | CIDR blocks for subnets | list | `["10.0.1.0/24", "10.0.2.0/24"]` |
| `availability_zones` | AZs for deployment | list | `["us-west-2a", "us-west-2b"]` |

### Optional Variables

| Variable | Description | Type | Default |
|----------|-------------|------|---------|
| `front_end_image` | Docker image for frontend | string | `""` |
| `front_end_port` | Frontend service port | number | `3000` |
| `dns_name` | Custom domain name | string | `""` |
| `certbot_email` | Email for SSL certificates | string | `""` |
| `environment` | Environment tag | string | `production` |
| `cname_records` | Map of CNAME records to create | map(string) | `{}` |
| `txt_records` | Map of TXT records to create | map(list(string)) | `{}` |
| `custom_dns_records` | Map of custom DNS records | map(object) | `{}` |

### Zero-Downtime Deployment Variables

| Variable | Description | Type | Default |
|----------|-------------|------|---------|
| `blue_green_enabled` | Enable blue-green deployment instead of rolling | bool | `false` |
| `active_target_group` | Currently active target group (blue or green) | string | `"blue"` |
| `enable_rollback` | Enable automatic rollback on deployment failure | bool | `true` |
| `rollback_timeout_minutes` | Timeout in minutes before triggering rollback | number | `5` |

## Usage

### 1. Clone the Repository

#### Option A: Direct Clone
```bash
git clone https://github.com/dev-ignis/aws-docker-deployment.git
cd aws-docker-deployment
```

#### Option B: As a Git Submodule
```bash
# In your parent project (common naming conventions)
git submodule add https://github.com/dev-ignis/aws-docker-deployment.git infra
# OR
git submodule add https://github.com/dev-ignis/aws-docker-deployment.git infrastructure
```

📖 **[Detailed Submodule Usage Guide](docs/submodule-usage.md)** - For managing this repo as a submodule

### 2. Configure Variables

Create a `terraform.tfvars` file:

```hcl
region              = "us-west-2"
ami                 = "ami-0c55b159cbfafe1f0"  # Ubuntu 20.04 LTS
instance_type       = "t2.micro"
instance_name       = "my-app"
key_name            = "my-aws-keypair"
backend_image       = "mycompany/backend:latest"
front_end_image     = "mycompany/frontend:latest"
backend_port        = 8080
front_end_port      = 3000
dns_name            = "myapp.example.com"
certbot_email       = "admin@example.com"
vpc_cidr            = "10.0.0.0/16"
subnet_cidrs        = ["10.0.1.0/24", "10.0.2.0/24"]
availability_zones  = ["us-west-2a", "us-west-2b"]
```

### 3. Initialize Terraform

```bash
terraform init
```

### 4. Plan Deployment

```bash
terraform plan
```

### 5. Apply Configuration

```bash
terraform apply
```

### 6. Access Your Application

After deployment, Terraform will output:
- Load balancer DNS name
- EC2 instance IDs
- DynamoDB table name

Access your application via the ALB DNS or your custom domain (if configured).

## Post-Deployment

### SSH Access

```bash
ssh -i path/to/your-key.pem ubuntu@<instance-ip>
```

### Container Management

```bash
# List running containers
docker ps

# View container logs
docker logs <container-name>

# Restart containers
docker restart <container-name>
```

### NGINX Configuration

The NGINX configuration is automatically generated based on your deployment settings. To modify:

1. SSH into the instance
2. Edit `/etc/nginx/sites-available/default`
3. Reload NGINX: `sudo systemctl reload nginx`

### Zero-Downtime Deployments

This infrastructure supports two deployment strategies:

#### Rolling Deployment (Default)
Sequential instance updates with health checks:

```bash
# Update backend application
terraform apply -var="backend_image=myapp/backend:v2.0"

# Update frontend application  
terraform apply -var="front_end_image=myapp/frontend:v2.0"
```

#### Blue-Green Deployment
Complete environment switching for instant rollback:

```bash
# Enable blue-green deployment
terraform apply -var="blue_green_enabled=true" -var="backend_image=myapp/backend:v2.0"

# After successful deployment, update active target group
terraform apply -var="blue_green_enabled=true" -var="active_target_group=green"
```

**📖 [Detailed Zero-Downtime Deployment Guide](docs/zero-downtime-deployments.md)**

### Manual Container Updates

For manual updates via SSH:

1. Push new images to your registry
2. SSH into instances and update containers
3. The ALB health checks ensure traffic routing to healthy instances

## Security Considerations

- EC2 instances are deployed in public subnets but protected by security groups
- Only necessary ports are exposed (80, 443, 22)
- SSL/TLS is enforced at the ALB level
- Consider implementing:
  - AWS WAF for additional protection
  - Private subnets for enhanced security
  - VPN or bastion host for SSH access
  - Secrets management via AWS Secrets Manager

## Monitoring & Logging

Recommended additions:
- CloudWatch alarms for ALB and EC2 metrics
- Application logs forwarding to CloudWatch Logs
- AWS X-Ray for distributed tracing
- Custom CloudWatch dashboards

## Cost Optimization

- Use appropriate instance types for your workload
- Consider Reserved Instances for production
- Enable ALB deletion protection for production
- Monitor DynamoDB usage and adjust capacity mode if needed
- Use S3 for static asset hosting

## Troubleshooting

### Common Issues

1. **Unhealthy targets in ALB**
   - Check security group rules
   - Verify health check endpoint (`/health`)
   - Review container logs

2. **Containers not starting**
   - Verify Docker image accessibility
   - Check instance user data logs: `/var/log/cloud-init-output.log`
   - Ensure sufficient instance resources

3. **SSL certificate issues**
   - Verify domain ownership
   - Check Route53 DNS propagation
   - Ensure ACM certificate is validated

### Debug Commands

```bash
# Check user data execution
sudo cat /var/log/cloud-init-output.log

# View NGINX logs
sudo tail -f /var/log/nginx/error.log
sudo tail -f /var/log/nginx/access.log

# Check Docker status
sudo systemctl status docker
docker ps -a
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For issues, questions, or contributions, please open an issue in the GitHub repository.