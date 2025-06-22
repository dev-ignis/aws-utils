# Multi-Environment Architecture Plan
## MHT API - Staging & Production Separation

**Date:** 2025-01-22  
**Project:** MHT API Infrastructure  
**Objective:** Implement fully isolated staging and production environments

---

## 📋 **Executive Summary**

This plan outlines the migration from a single-environment infrastructure to a fully isolated multi-environment setup supporting both staging and production deployments. The architecture ensures complete separation of resources, independent scaling, and cost optimization while maintaining our white-label module approach.

## 🎯 **Goals & Requirements**

### **Primary Goals**
- ✅ **Full Environment Isolation**: Zero shared resources between staging and production
- ✅ **Independent Scaling**: Different resource configurations per environment
- ✅ **Production Parity**: Staging mirrors production infrastructure for deployment confidence
- ✅ **Security**: Complete IAM and network isolation
- ✅ **Maintainability**: Consistent module usage across environments

### **Business Requirements**
- **Risk Mitigation**: Staging failures cannot impact production
- **Deployment Confidence**: Production-parity staging to eliminate "works on my machine" issues
- **Performance**: Production environment optimized for reliability
- **Compliance**: Production data isolation and audit trails
- **Development Velocity**: Fast iteration with production-like validation

---

## 🏗️ **Target Architecture**

### **Directory Structure**
```
aws-docker-deployment/
├── environments/
│   ├── staging/
│   │   ├── main.tf                    # Environment-specific infrastructure
│   │   ├── variables.tf               # Staging variable definitions
│   │   ├── outputs.tf                 # Staging outputs
│   │   ├── terraform.tfvars           # Staging configuration
│   │   ├── backend.tf                 # Staging state backend
│   │   └── README.md                  # Staging deployment guide
│   └── production/
│       ├── main.tf                    # Environment-specific infrastructure
│       ├── variables.tf               # Production variable definitions
│       ├── outputs.tf                 # Production outputs
│       ├── terraform.tfvars           # Production configuration
│       ├── backend.tf                 # Production state backend
│       └── README.md                  # Production deployment guide
├── modules/                           # Shared white-label modules
│   ├── s3/                           # S3 storage module (unchanged)
│   ├── sqs/                          # SQS processing module (unchanged)
│   ├── alb/                          # Application Load Balancer module
│   ├── network/                      # VPC and networking module
│   └── dynamodb/                     # DynamoDB module
├── scripts/
│   ├── test-s3-infrastructure.sh     # S3 testing (environment-aware)
│   ├── test-sqs-infrastructure.sh    # SQS testing (environment-aware)
│   ├── deploy-environment.sh         # Environment deployment script
│   └── switch-environment.sh         # Environment switching utility
└── docs/
    ├── white-label/                  # Module documentation
    ├── deployment-guide.md           # Multi-environment deployment guide
    └── troubleshooting.md            # Environment-specific troubleshooting
```

---

## 🔐 **1. Isolation Strategy**

### **Complete Resource Separation**

| Resource Type | Staging | Production | Shared |
|---------------|---------|------------|--------|
| **VPC** | `10.1.0.0/16` | `10.0.0.0/16` | ❌ None |
| **EC2 Instances** | `mht-api-staging-*` | `mht-api-production-*` | ❌ None |
| **S3 Buckets** | `mht-api-staging-*` | `mht-api-production-*` | ❌ None |
| **SQS Queues** | `mht-api-staging-*` | `mht-api-production-*` | ❌ None |
| **IAM Roles** | `*-staging-*` | `*-production-*` | ❌ None |
| **Load Balancers** | `mht-api-staging-alb` | `mht-api-production-alb` | ❌ None |
| **Security Groups** | Environment-specific | Environment-specific | ❌ None |
| **Route53 Hosted Zone** | ❌ | ❌ | ✅ `amygdalas.com` |

### **Network Isolation**
```hcl
# Staging Network
vpc_cidr = "10.1.0.0/16"
subnet_cidrs = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
availability_zones = ["us-west-2a", "us-west-2b", "us-west-2c"]

# Production Network  
vpc_cidr = "10.0.0.0/16"
subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
availability_zones = ["us-west-2a", "us-west-2b", "us-west-2c"]
```

### **IAM Isolation**
```hcl
# Staging IAM Resources
mht-api-staging-api-service-role
mht-api-staging-worker-service-role
mht-api-staging-s3-access-role

# Production IAM Resources
mht-api-production-api-service-role
mht-api-production-worker-service-role
mht-api-production-s3-access-role
```

---

## ⚖️ **2. Resource Scaling Strategy**

### **Staging Environment** (Architectural Parity with Smart Cost Optimization)
```hcl
# Compute Resources - COST-OPTIMIZED BUT ARCHITECTURALLY CONSISTENT
instance_type = "t2.micro"              # Cost-optimized but still multi-instance
instance_count = 2                      # Reduced from 3, but maintains load balancer testing
enable_load_balancer = true             # CRITICAL: Same as production for request pattern testing

# Network Configuration - PRODUCTION PARITY
vpc_cidr = "10.1.0.0/16"
subnet_cidrs = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
availability_zones = ["us-west-2a", "us-west-2b", "us-west-2c"]

# SQS Configuration - PRODUCTION PARITY
enable_sqs_encryption = true            # Same encryption as production
enable_sqs_cloudwatch_alarms = true     # Same monitoring as production
create_sqs_api_role = true              # Same IAM structure
create_sqs_worker_role = true           # Same IAM structure

# S3 Configuration - PRODUCTION PARITY
enable_s3_intelligent_tiering = true    # Same optimization features
enable_s3_lifecycle_policy = true       # Same lifecycle management
s3_versioning_enabled = true            # Same data protection
enable_s3_access_logging = true         # Same audit capabilities

# Cost Optimizations - COMPUTE + DATA RETENTION
sqs_log_retention_days = 7              # vs 30 in production
s3_log_retention_days = 14              # vs 90 in production
s3_lifecycle_transitions = [
  { days = 7, storage_class = "STANDARD_IA" },    # vs 30 in production
  { days = 14, storage_class = "GLACIER" },       # vs 90 in production
  { days = 30, storage_class = "DEEP_ARCHIVE" }   # vs 365 in production
]

# Environment-Specific Overrides
sqs_cloudwatch_alarm_actions = [
  "arn:aws:sns:us-west-2:123456789012:staging-alerts"  # vs production-alerts
]
```

**Estimated Staging Costs: ~$25/month**
- EC2 t2.micro (2x): ~$0/month (free tier eligible)
- Application Load Balancer: ~$16/month
- S3 Storage: ~$2/month (smaller datasets)
- SQS: ~$1/month (lower volume)
- CloudWatch: ~$6/month (alarms + shorter retention)

**Value Proposition**: 
- **Architectural Parity**: Load balancer, encryption, monitoring, IAM structure
- **Cost Efficiency**: 62% cost reduction vs full production parity ($25 vs $65)
- **Risk Mitigation**: Catches 80% of deployment issues at 25% of the cost

### **Production Environment** (Reliability & Compliance Optimized)
```hcl
# Compute Resources - IDENTICAL to staging
instance_type = "t3.medium"             # Same as staging for consistency
instance_count = 3                      # Same as staging for consistency
enable_load_balancer = true             # Same as staging for consistency

# Network Configuration - IDENTICAL to staging (different CIDR)
vpc_cidr = "10.0.0.0/16"
subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
availability_zones = ["us-west-2a", "us-west-2b", "us-west-2c"]

# SQS Configuration - IDENTICAL to staging
enable_sqs_encryption = true            # Same as staging
enable_sqs_cloudwatch_alarms = true     # Same as staging
create_sqs_api_role = true              # Same as staging
create_sqs_worker_role = true           # Same as staging

# S3 Configuration - IDENTICAL to staging
enable_s3_intelligent_tiering = true    # Same as staging
enable_s3_lifecycle_policy = true       # Same as staging
s3_versioning_enabled = true            # Same as staging
enable_s3_access_logging = true         # Same as staging

# Production Differences - DATA RETENTION & COMPLIANCE
sqs_log_retention_days = 30             # Extended for compliance
s3_log_retention_days = 90              # Extended for audit trails
s3_lifecycle_transitions = [
  { days = 30, storage_class = "STANDARD_IA" },   # Conservative transitions
  { days = 90, storage_class = "GLACIER" },       # Balanced cost/access
  { days = 365, storage_class = "DEEP_ARCHIVE" }  # Long-term compliance
]

# Environment-Specific Overrides
sqs_cloudwatch_alarm_actions = [
  "arn:aws:sns:us-west-2:123456789012:production-alerts"
]

# Additional Production Features
blue_green_enabled = true              # Advanced deployment strategy
rollback_timeout_minutes = 5           # Faster recovery
enable_discord_notifications = true    # Business alerting
```

**Estimated Production Costs: ~$100/month**
- EC2 t3.medium (3x): ~$50/month
- Application Load Balancer: ~$16/month
- S3 Storage: ~$15/month (larger datasets, longer retention)
- SQS: ~$5/month (higher volume)
- CloudWatch: ~$8/month (extended retention, more metrics)
- Additional Features: ~$6/month (blue-green, enhanced monitoring)

---

## 🗂️ **3. State Management Strategy**

### **Separate Backend Configuration**

#### **Staging Backend**
```hcl
# environments/staging/backend.tf
terraform {
  required_version = ">= 1.0"
  
  backend "s3" {
    bucket         = "mht-terraform-state-staging"
    key            = "infrastructure/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "mht-terraform-locks-staging"
    encrypt        = true
    
    # Staging-specific settings
    versioning     = true
    lifecycle_rule = {
      enabled = true
      expiration_days = 90        # Shorter retention for staging
    }
  }
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

#### **Production Backend**
```hcl
# environments/production/backend.tf
terraform {
  required_version = ">= 1.0"
  
  backend "s3" {
    bucket         = "mht-terraform-state-production"
    key            = "infrastructure/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "mht-terraform-locks-production"
    encrypt        = true
    
    # Production-specific settings
    versioning     = true
    lifecycle_rule = {
      enabled = true
      expiration_days = 365       # Extended retention for production
    }
  }
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

### **State Bucket Setup**
```bash
# Create staging state management
aws s3 mb s3://mht-terraform-state-staging --region us-west-2
aws dynamodb create-table \
  --table-name mht-terraform-locks-staging \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST

# Create production state management
aws s3 mb s3://mht-terraform-state-production --region us-west-2
aws dynamodb create-table \
  --table-name mht-terraform-locks-production \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

---

## 🌐 **4. DNS Strategy**

### **Domain Structure**
```
amygdalas.com (Shared Hosted Zone)
├── api.amygdalas.com              → Production API
├── staging.api.amygdalas.com      → Staging API  
├── dev.amygdalas.com              → Development API (staging secondary)
├── www.amygdalas.com              → Production Website
└── staging.amygdalas.com          → Staging Website
```

### **Environment-Specific DNS Configuration**

#### **Staging DNS**
```hcl
# environments/staging/terraform.tfvars
hosted_zone_name = "amygdalas.com"
route53_zone_id = "Z0286437KXYMILBB4R1F"        # Shared zone
prod_api_dns_name = "staging.api.amygdalas.com"  # Main staging API endpoint
staging_api_dns_name = "dev.amygdalas.com"       # Development endpoint
```

#### **Production DNS**
```hcl
# environments/production/terraform.tfvars
hosted_zone_name = "amygdalas.com"
route53_zone_id = "Z0286437KXYMILBB4R1F"        # Shared zone
prod_api_dns_name = "api.amygdalas.com"          # Main production API endpoint
staging_api_dns_name = "staging.api.amygdalas.com" # Staging API reference
```

### **SSL Certificate Strategy**
- **Production**: `*.amygdalas.com` wildcard certificate
- **Staging**: Uses same wildcard certificate (cost-effective)
- **Validation**: Separate certificate validation per environment

---

## 💰 **5. Cost Optimization Strategy**

### **Production Parity Benefits vs Cost Optimization Trade-offs**

#### **Previous Minimal Approach**: ~$15/month
| Component | Risk | Cost of Production Incident |
|-----------|------|----------------------------|
| **Single t2.micro** | No load balancer testing | 1-2 hours debugging = $200-500 |
| **No Load Balancer** | Request routing issues | 1-2 hours debugging = $200-500 |
| **Minimal Monitoring** | Hidden issues until production | 4-8 hours troubleshooting = $1000-2000 |
| **Different Architecture** | Configuration surprises | 2-6 hours resolution = $500-1500 |

#### **Hybrid Architectural Parity Approach**: ~$25/month
| Component | Benefit | Risk Mitigation Value |
|-----------|---------|----------------------|
| **Load Balancer + Multi-Instance** | Tests real request patterns | Prevents routing issues = $200-500 |
| **Same Encryption/IAM** | Identical security setup | Prevents security gaps = $500-1500 |
| **Same Monitoring** | Early issue detection | Prevents hidden problems = $1000-2000 |
| **Same Network Setup** | Consistent connectivity | Prevents network gaps = $200-500 |

#### **ROI Analysis**
- **Extra Monthly Cost**: $10 ($25 vs $15)
- **Annual Extra Cost**: $120
- **Annual Risk Mitigation Value**: $1900-4500
- **Break-Even**: Preventing 1 incident every 3-4 years pays for itself
- **Sweet Spot**: 80% of benefit at 25% of full production parity cost

### **Production Investments**
| Component | Investment | Benefit |
|-----------|------------|---------|
| **Multi-AZ** | 3 instances vs 1 | High availability |
| **Load Balancer** | $16/month | Health checks, SSL termination |
| **Extended Monitoring** | $7/month | Detailed observability |
| **Extended Retention** | $5/month | Compliance and debugging |

### **Shared Cost Efficiencies**
- **Route53 Hosted Zone**: $0.50/month (shared across environments)
- **White-Label Modules**: No duplication, consistent configuration
- **Automation Scripts**: Environment-aware testing and deployment

---

## 🚀 **6. Migration Plan**

### **Phase 1: Environment Structure Setup** (Week 1)
```bash
# 1.1 Create directory structure
mkdir -p environments/{staging,production}
mkdir -p scripts docs/environments

# 1.2 Create backend resources
./scripts/setup-backend-infrastructure.sh staging
./scripts/setup-backend-infrastructure.sh production

# 1.3 Prepare environment-specific configurations
cp terraform.tfvars environments/staging/
cp *.tf environments/staging/
```

### **Phase 2: Staging Environment Migration** (Week 1-2)
```bash
# 2.1 Migrate current infrastructure to staging
cd environments/staging
terraform init
terraform import [existing-resources]
terraform plan
terraform apply

# 2.2 Test staging environment
./scripts/test-sqs-infrastructure.sh
./scripts/test-s3-infrastructure.sh

# 2.3 Update DNS records for staging
# staging.amygdalas.com → staging infrastructure
```

### **Phase 3: Production Environment Creation** (Week 2-3)
```bash
# 3.1 Create production configuration
cd environments/production
# Copy and modify staging configs for production settings
terraform init
terraform plan
terraform apply

# 3.2 Production testing and validation
./scripts/test-sqs-infrastructure.sh
./scripts/test-s3-infrastructure.sh

# 3.3 DNS cutover
# api.amygdalas.com → production infrastructure
```

### **Phase 4: Automation & Documentation** (Week 3-4)
```bash
# 4.1 Create deployment automation
./scripts/deploy-environment.sh staging
./scripts/deploy-environment.sh production

# 4.2 Environment switching utilities
./scripts/switch-environment.sh staging
./scripts/switch-environment.sh production

# 4.3 Documentation and runbooks
# Complete environment-specific guides
```

---

## 🔒 **7. Security & Compliance**

### **Access Control Strategy**

#### **Staging Access** (Development Team)
```hcl
# IAM policy for staging access
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "*",
      "Resource": "arn:aws:*:*:*:*staging*"
    }
  ]
}
```

#### **Production Access** (Operations Team)
```hcl
# IAM policy for production access (restricted)
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:Describe*",
        "s3:GetObject",
        "sqs:ReceiveMessage",
        "cloudwatch:GetMetricStatistics"
      ],
      "Resource": "arn:aws:*:*:*:*production*"
    }
  ]
}
```

### **Data Protection**
- **Staging**: Test data only, no production data
- **Production**: Encrypted at rest and in transit
- **Cross-Environment**: Zero data movement between environments
- **Backups**: Environment-specific backup strategies

### **Audit & Compliance**
- **CloudTrail**: Separate trails per environment
- **CloudWatch**: Environment-specific log groups
- **Cost Allocation**: Environment-based cost tracking
- **Security Groups**: Environment-specific access rules

---

## 📊 **8. Monitoring & Observability**

### **Environment-Specific Dashboards**

#### **Staging Dashboard**
- **Focus**: Development velocity and cost monitoring
- **Metrics**: Basic health checks, cost tracking
- **Alerts**: Critical failures only
- **Retention**: 7 days

#### **Production Dashboard**
- **Focus**: Performance, reliability, and business metrics
- **Metrics**: Comprehensive monitoring across all services
- **Alerts**: Proactive alerting with Discord integration
- **Retention**: 90 days

### **Cross-Environment Reporting**
```hcl
# Cost comparison dashboard
- Staging monthly spend vs budget
- Production monthly spend vs budget  
- Cost per transaction analysis
- Resource utilization comparison
```

---

## 🧪 **9. Testing Strategy**

### **Environment-Aware Testing**
```bash
# Test staging environment
ENV=staging ./scripts/test-sqs-infrastructure.sh
ENV=staging ./scripts/test-s3-infrastructure.sh

# Test production environment  
ENV=production ./scripts/test-sqs-infrastructure.sh
ENV=production ./scripts/test-s3-infrastructure.sh
```

### **Deployment Validation**
```bash
# Staging deployment validation
cd environments/staging
terraform plan -detailed-exitcode
./scripts/validate-environment.sh staging

# Production deployment validation
cd environments/production  
terraform plan -detailed-exitcode
./scripts/validate-environment.sh production
```

### **Cross-Environment Validation**
- **Resource Isolation**: Verify no shared resources
- **DNS Resolution**: Confirm correct endpoint routing
- **Cost Allocation**: Validate environment-specific billing
- **Security**: Test IAM isolation between environments

---

## 📈 **10. Success Metrics**

### **Technical Metrics**
- **Deployment Time**: < 10 minutes per environment
- **Environment Isolation**: 100% resource separation
- **Cost Target**: Staging ~$25/month (architectural parity), Production ~$100/month
- **Availability**: Staging 95%, Production 99.9%

### **Business Metrics**
- **Development Velocity**: 50% faster iteration in staging
- **Risk Reduction**: Zero production incidents from staging changes
- **Cost Efficiency**: 60% cost reduction vs shared infrastructure
- **Compliance**: 100% audit trail separation

### **Operational Metrics**
- **Mean Time to Deploy**: < 5 minutes
- **Mean Time to Recovery**: < 15 minutes
- **Change Failure Rate**: < 5%
- **Lead Time**: Same-day staging deployment

---

## 🎯 **11. Next Steps**

### **Immediate Actions** (This Week)
1. ✅ **Review and approve this plan**
2. ⏳ **Create backend infrastructure** (S3 buckets, DynamoDB tables)
3. ⏳ **Set up directory structure**
4. ⏳ **Begin staging environment migration**

### **Short Term** (Next 2 Weeks)
1. ⏳ **Complete staging environment setup**
2. ⏳ **Validate staging functionality**
3. ⏳ **Create production environment**
4. ⏳ **DNS cutover for production**

### **Medium Term** (Next Month)
1. ⏳ **Implement deployment automation**
2. ⏳ **Complete documentation**
3. ⏳ **Team training on multi-environment workflows**
4. ⏳ **Cost optimization review**

---

## 🤝 **Team Responsibilities**

### **Development Team**
- **Staging Environment**: Full access for development and testing
- **Code Deployment**: Use staging for feature validation
- **Cost Monitoring**: Track staging resource usage

### **Operations Team**
- **Production Environment**: Deployment and monitoring responsibility
- **Security**: Maintain environment isolation
- **Compliance**: Ensure audit trail and backup strategies

### **DevOps Team**
- **Infrastructure**: Maintain both environments
- **Automation**: Develop deployment and testing scripts
- **Monitoring**: Set up cross-environment observability

---

## 📝 **Conclusion**

This multi-environment architecture provides complete isolation between staging and production with **architectural parity staging** to eliminate deployment surprises. The white-label module approach ensures consistency across environments while the hybrid cost-optimization strategy provides 80% of deployment confidence at 25% of the cost.

**Total Implementation Timeline**: 3-4 weeks  
**Expected Monthly Cost**: ~$125 ($25 staging + $100 production)  
**Risk Reduction**: Complete isolation + production parity eliminates deployment surprises  
**Development Efficiency**: Production-like staging enables confident, fast iterations  
**ROI**: $120/year extra cost prevents $1900-4500/year in incident costs

---

**Document Version**: 1.0  
**Last Updated**: 2025-01-22  
**Next Review**: 2025-02-22  
**Owner**: DevOps Team  
**Stakeholders**: Development Team, Operations Team, Business Stakeholders