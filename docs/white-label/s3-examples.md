# S3 Storage Module - White Label Configuration Examples

This document provides comprehensive tfvars examples for deploying the S3 storage module across different use cases and client scenarios.

## Table of Contents

1. [Analytics Data Lake](#analytics-data-lake)
2. [Media Storage Platform](#media-storage-platform)
3. [Multi-Tenant SaaS](#multi-tenant-saas)
4. [Enterprise Backup Solution](#enterprise-backup-solution)
5. [Cross-Account Data Sharing](#cross-account-data-sharing)
6. [Development/Staging Environment](#developmentstaging-environment)

---

## Analytics Data Lake

Perfect for companies building data analytics platforms or business intelligence solutions.

```hcl
# terraform.tfvars - Analytics Data Lake Configuration

# Basic Infrastructure
instance_name = "analytics-platform"
environment   = "production"

# S3 Analytics Configuration
s3_bucket_name_suffix = "data-lake"
s3_use_case          = "analytics-data-lake"

# Data Organization for Analytics
s3_primary_data_prefix     = "raw-data/"
s3_secondary_data_prefixes = [
  "events/",
  "user-behavior/",
  "transactions/",
  "logs/",
  "metrics/"
]

# Aggressive Cost Optimization for Large Data
enable_s3_intelligent_tiering = true
enable_s3_lifecycle_policy   = true
s3_lifecycle_transitions = [
  {
    days          = 30
    storage_class = "STANDARD_IA"
  },
  {
    days          = 90
    storage_class = "GLACIER"
  },
  {
    days          = 180
    storage_class = "DEEP_ARCHIVE"
  }
]

# Analytics-Specific IAM Roles
create_s3_read_only_role = true    # For BI tools and analysts
create_s3_admin_role     = true    # For data engineers

# Temporary Data for ETL Processes
s3_temp_prefixes = {
  "processing" = {
    prefix          = "processing"
    expiration_days = 7
  }
  "staging" = {
    prefix          = "staging"
    expiration_days = 3
  }
  "failed-jobs" = {
    prefix          = "failed"
    expiration_days = 30
  }
}

# Enhanced Monitoring for Analytics
enable_s3_access_logging = true
s3_log_retention_days   = 90
create_s3_partition_examples = true
```

---

## Media Storage Platform

Ideal for companies providing media hosting, CDN, or content management services.

```hcl
# terraform.tfvars - Media Storage Platform Configuration

# Basic Infrastructure
instance_name = "media-platform"
environment   = "production"

# S3 Media Configuration
s3_bucket_name_suffix = "media-storage"
s3_use_case          = "media-content-delivery"

# Media-Specific Data Organization
s3_primary_data_prefix     = "uploads/"
s3_secondary_data_prefixes = [
  "images/",
  "videos/",
  "documents/",
  "thumbnails/",
  "processed/"
]

# Media-Optimized Lifecycle (Keep recent files hot)
enable_s3_intelligent_tiering = true
enable_s3_lifecycle_policy   = true
s3_lifecycle_transitions = [
  {
    days          = 60    # Keep media accessible longer
    storage_class = "STANDARD_IA"
  },
  {
    days          = 180
    storage_class = "GLACIER"
  },
  {
    days          = 365
    storage_class = "DEEP_ARCHIVE"
  }
]

# Security for Media Platform
s3_versioning_enabled = true
s3_kms_key_id        = "arn:aws:kms:us-west-2:123456789012:key/12345678-1234-1234-1234-123456789012"

# Media Processing Temporary Storage
s3_temp_prefixes = {
  "upload-queue" = {
    prefix          = "upload-queue"
    expiration_days = 1
  }
  "processing" = {
    prefix          = "processing"
    expiration_days = 7
  }
  "thumbnails-temp" = {
    prefix          = "thumb-temp"
    expiration_days = 3
  }
}

# Standard Monitoring
enable_s3_access_logging = true
s3_log_retention_days   = 60
create_s3_partition_examples = false  # Media doesn't need Athena partitions
```

---

## Multi-Tenant SaaS

Configuration for SaaS platforms serving multiple clients with isolated data.

```hcl
# terraform.tfvars - Multi-Tenant SaaS Configuration

# Basic Infrastructure
instance_name = "saas-platform"
environment   = "production"

# S3 Multi-Tenant Configuration
s3_bucket_name_suffix = "tenant-data"
s3_use_case          = "multi-tenant-saas"

# Tenant Isolation via Prefixes
s3_primary_data_prefix     = "tenant-data/"
s3_secondary_data_prefixes = [
  "tenant-a/",
  "tenant-b/",
  "tenant-c/",
  "shared/",
  "backups/",
  "exports/"
]

# Balanced Cost Optimization
enable_s3_intelligent_tiering = true
enable_s3_lifecycle_policy   = true
s3_lifecycle_transitions = [
  {
    days          = 45
    storage_class = "STANDARD_IA"
  },
  {
    days          = 120
    storage_class = "GLACIER"
  },
  {
    days          = 270
    storage_class = "DEEP_ARCHIVE"
  }
]

# Cross-Account Access for Enterprise Clients
s3_trusted_accounts = [
  "111122223333",  # Enterprise Client A
  "444455556666"   # Enterprise Client B
]

# Multiple IAM Roles for Different Access Levels
create_s3_read_only_role = true    # For tenant read-only access
create_s3_admin_role     = true    # For platform administrators

# SaaS-Specific Temporary Storage
s3_temp_prefixes = {
  "exports" = {
    prefix          = "exports"
    expiration_days = 7
  }
  "imports" = {
    prefix          = "imports"
    expiration_days = 3
  }
  "tenant-migration" = {
    prefix          = "migration"
    expiration_days = 30
  }
}

# Enhanced Monitoring for SaaS
enable_s3_access_logging = true
s3_log_retention_days   = 90
create_s3_partition_examples = true
```

---

## Enterprise Backup Solution

For companies providing enterprise backup and disaster recovery services.

```hcl
# terraform.tfvars - Enterprise Backup Solution Configuration

# Basic Infrastructure
instance_name = "backup-service"
environment   = "production"

# S3 Backup Configuration
s3_bucket_name_suffix = "enterprise-backup"
s3_use_case          = "disaster-recovery-backup"

# Backup-Specific Organization
s3_primary_data_prefix     = "backups/"
s3_secondary_data_prefixes = [
  "daily-backups/",
  "weekly-backups/",
  "monthly-backups/",
  "system-images/",
  "database-dumps/",
  "file-archives/"
]

# Long-Term Retention Lifecycle
enable_s3_intelligent_tiering = true
enable_s3_lifecycle_policy   = true
s3_lifecycle_transitions = [
  {
    days          = 7     # Move to IA quickly for backups
    storage_class = "STANDARD_IA"
  },
  {
    days          = 30    # Archive frequently
    storage_class = "GLACIER"
  },
  {
    days          = 90    # Deep archive for long-term retention
    storage_class = "DEEP_ARCHIVE"
  }
]

# Maximum Security for Backups
s3_versioning_enabled = true
s3_kms_key_id        = "arn:aws:kms:us-west-2:123456789012:key/backup-key-id"

# Cross-Account for Enterprise Clients
s3_trusted_accounts = [
  "123456789012",  # Client A Production Account
  "210987654321",  # Client A DR Account
  "345678901234"   # Client B Account
]

# Admin-Only Access for Backup Service
create_s3_read_only_role = false   # No read-only for backup service
create_s3_admin_role     = true    # Full admin for backup operations

# Backup Process Temporary Storage
s3_temp_prefixes = {
  "backup-staging" = {
    prefix          = "staging"
    expiration_days = 2
  }
  "failed-backups" = {
    prefix          = "failed"
    expiration_days = 14
  }
  "verification" = {
    prefix          = "verify"
    expiration_days = 7
  }
}

# Extended Monitoring for Compliance
enable_s3_access_logging = true
s3_log_retention_days   = 365  # Keep logs for compliance
create_s3_partition_examples = false
```

---

## Cross-Account Data Sharing

Configuration for data sharing platforms or B2B data exchange services.

```hcl
# terraform.tfvars - Cross-Account Data Sharing Configuration

# Basic Infrastructure
instance_name = "data-exchange"
environment   = "production"

# S3 Data Sharing Configuration
s3_bucket_name_suffix = "data-exchange"
s3_use_case          = "cross-account-data-sharing"

# Data Sharing Organization
s3_primary_data_prefix     = "shared-data/"
s3_secondary_data_prefixes = [
  "public-datasets/",
  "partner-data/",
  "marketplace-data/",
  "api-exports/",
  "analytics-feeds/"
]

# Moderate Lifecycle for Active Data
enable_s3_intelligent_tiering = true
enable_s3_lifecycle_policy   = true
s3_lifecycle_transitions = [
  {
    days          = 60
    storage_class = "STANDARD_IA"
  },
  {
    days          = 180
    storage_class = "GLACIER"
  }
  # No DEEP_ARCHIVE for active data sharing
]

# No KMS for Public Data Sharing
s3_versioning_enabled = true
s3_kms_key_id        = null

# Multiple Partner Accounts
s3_trusted_accounts = [
  "111111111111",  # Partner A
  "222222222222",  # Partner B  
  "333333333333",  # Partner C
  "444444444444",  # Data Consumer A
  "555555555555"   # Data Consumer B
]

# Both Read-Only and Admin Access
create_s3_read_only_role = true    # For data consumers
create_s3_admin_role     = true    # For data publishers

# Data Exchange Temporary Storage
s3_temp_prefixes = {
  "incoming" = {
    prefix          = "incoming"
    expiration_days = 7
  }
  "processing" = {
    prefix          = "processing"
    expiration_days = 5
  }
  "quarantine" = {
    prefix          = "quarantine"
    expiration_days = 30
  }
}

# Enhanced Monitoring for Data Sharing
enable_s3_access_logging = true
s3_log_retention_days   = 180
create_s3_partition_examples = true
```

---

## Development/Staging Environment

Lightweight configuration for development and testing environments.

```hcl
# terraform.tfvars - Development/Staging Configuration

# Basic Infrastructure
instance_name = "dev-platform"
environment   = "development"

# S3 Development Configuration
s3_bucket_name_suffix = "dev-storage"
s3_use_case          = "development-testing"

# Simple Development Organization
s3_primary_data_prefix     = "dev-data/"
s3_secondary_data_prefixes = [
  "test-data/",
  "mock-data/",
  "fixtures/"
]

# Aggressive Cleanup for Dev Environment
enable_s3_intelligent_tiering = false  # Not needed for dev
enable_s3_lifecycle_policy   = true
s3_lifecycle_transitions = [
  {
    days          = 7     # Quick cleanup in dev
    storage_class = "STANDARD_IA"
  },
  {
    days          = 30
    storage_class = "GLACIER"
  }
]

# Basic Security for Development
s3_versioning_enabled = false  # Not needed for dev
s3_kms_key_id        = null
s3_trusted_accounts  = []

# No Additional Roles Needed
create_s3_read_only_role = false
create_s3_admin_role     = false

# Aggressive Temporary Data Cleanup
s3_temp_prefixes = {
  "temp" = {
    prefix          = "temp"
    expiration_days = 1
  }
  "test-runs" = {
    prefix          = "test-runs"
    expiration_days = 3
  }
}

# Minimal Monitoring for Dev
enable_s3_access_logging = false
s3_log_retention_days   = 7
create_s3_partition_examples = true  # For testing
```

---

## Variable Reference Quick Guide

| Variable | Purpose | Common Values |
|----------|---------|---------------|
| `s3_bucket_name_suffix` | Bucket purpose identifier | `"analytics"`, `"media"`, `"backup"`, `"storage"` |
| `s3_use_case` | Resource naming context | `"data-analytics"`, `"media-storage"`, `"backup"` |
| `s3_primary_data_prefix` | Main data location | `"data/"`, `"uploads/"`, `"backups/"` |
| `s3_secondary_data_prefixes` | Additional data streams | Multi-tenant, different data types |
| `s3_trusted_accounts` | Cross-account access | List of AWS account IDs |
| `create_s3_read_only_role` | Analytics/consumer access | `true` for analytics use cases |
| `create_s3_admin_role` | Administrative access | `true` for managed services |
| `s3_temp_prefixes` | Temporary data management | Processing, staging, failed jobs |

## Best Practices

1. **Use descriptive suffixes**: Choose bucket name suffixes that clearly indicate the purpose
2. **Plan your prefixes**: Design prefix structure before deployment for optimal organization
3. **Consider lifecycle early**: Set appropriate lifecycle rules based on data access patterns
4. **Security first**: Use KMS encryption for sensitive data, enable versioning for important data
5. **Monitor costs**: Enable intelligent tiering and lifecycle policies for cost optimization
6. **Plan for scale**: Use secondary prefixes for multi-tenant or multi-purpose scenarios