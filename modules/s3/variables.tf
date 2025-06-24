# S3 Storage Module Variables - White Label Ready

variable "instance_name" {
  description = "Name prefix for all resources"
  type        = string
}

variable "bucket_name_suffix" {
  description = "Suffix for the S3 bucket name (e.g., 'data-lake', 'analytics', 'storage')"
  type        = string
  default     = "storage"
}

variable "use_case" {
  description = "Use case description for resource naming and tagging"
  type        = string
  default     = "data-storage"
}

variable "environment" {
  description = "Environment name (staging, production, development)"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# S3 Bucket Configuration
variable "versioning_enabled" {
  description = "Enable S3 bucket versioning"
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "KMS key ID for S3 encryption (optional, uses AES256 if not provided)"
  type        = string
  default     = null
}

# Intelligent Tiering Configuration
variable "enable_intelligent_tiering" {
  description = "Enable S3 Intelligent Tiering"
  type        = bool
  default     = true
}

variable "primary_data_prefix" {
  description = "Primary prefix for data objects to apply intelligent tiering"
  type        = string
  default     = "data/"
}

variable "secondary_data_prefixes" {
  description = "Additional prefixes for data objects (for multi-tenant or multi-purpose buckets)"
  type        = list(string)
  default     = []
}

variable "tiering_configurations" {
  description = "List of intelligent tiering configurations"
  type = list(object({
    access_tier = string
    days        = number
  }))
  default = [
    {
      access_tier = "ARCHIVE_ACCESS"
      days        = 90
    },
    {
      access_tier = "DEEP_ARCHIVE_ACCESS"
      days        = 180
    }
  ]
}

# Lifecycle Policy Configuration
variable "enable_lifecycle_policy" {
  description = "Enable S3 lifecycle policy"
  type        = bool
  default     = true
}

variable "lifecycle_transitions" {
  description = "List of lifecycle transition rules"
  type = list(object({
    days          = number
    storage_class = string
  }))
  default = [
    {
      days          = 30
      storage_class = "STANDARD_IA"
    },
    {
      days          = 90
      storage_class = "GLACIER"
    },
    {
      days          = 365
      storage_class = "DEEP_ARCHIVE"
    }
  ]
}

variable "noncurrent_version_transition_days" {
  description = "Days after which non-current versions transition to IA"
  type        = number
  default     = 30
}

variable "noncurrent_version_expiration_days" {
  description = "Days after which non-current versions are deleted"
  type        = number
  default     = 90
}

variable "multipart_upload_cleanup_days" {
  description = "Days after which incomplete multipart uploads are cleaned up"
  type        = number
  default     = 7
}

# Temporary Data Configuration
variable "temp_prefixes" {
  description = "Map of temporary data prefixes and their expiration days"
  type = map(object({
    prefix           = string
    expiration_days  = number
  }))
  default = {
    "temp" = {
      prefix          = "temp"
      expiration_days = 7
    }
  }
}

# IAM Configuration
variable "trusted_services" {
  description = "List of AWS services that can assume the storage access role"
  type        = list(string)
  default = [
    "ec2.amazonaws.com",
    "lambda.amazonaws.com",
    "kinesis.amazonaws.com",
    "firehose.amazonaws.com",
    "glue.amazonaws.com",
    "ecs-tasks.amazonaws.com"
  ]
}

variable "trusted_accounts" {
  description = "List of AWS account IDs that can assume the storage access role (for cross-account access)"
  type        = list(string)
  default     = []
}

variable "s3_permissions" {
  description = "List of S3 permissions for the storage access role"
  type        = list(string)
  default = [
    "s3:PutObject",
    "s3:PutObjectAcl",
    "s3:GetObject",
    "s3:GetObjectVersion",
    "s3:DeleteObject",
    "s3:ListBucket"
  ]
}

variable "create_read_only_role" {
  description = "Create an additional read-only IAM role for analytics/reporting"
  type        = bool
  default     = false
}

variable "create_admin_role" {
  description = "Create an administrative IAM role with full bucket access"
  type        = bool
  default     = false
}

# Bucket Policy Configuration
variable "additional_bucket_policy_statements" {
  description = "Additional bucket policy statements to include"
  type        = list(any)
  default     = []
}

# Notification Configuration
variable "notification_configurations" {
  description = "List of S3 bucket notification configurations"
  type = list(object({
    lambda_function_arn = string
    events              = list(string)
    filter_prefix       = string
    filter_suffix       = string
  }))
  default = []
}

# CloudWatch Logging Configuration
variable "enable_access_logging" {
  description = "Enable CloudWatch access logging for S3"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 30
}

# Athena Partitioning Configuration
variable "setup_athena_partitions" {
  description = "Create partition structure for Athena queries"
  type        = bool
  default     = true
}

variable "partition_format" {
  description = "Partition format for Athena queries (year/month/day/hour)"
  type        = string
  default     = "year=%Y/month=%m/day=%d/hour=%H"
  validation {
    condition     = can(regex("year=.*month=.*day=.*hour=", var.partition_format))
    error_message = "Partition format must include year, month, day, and hour components."
  }
}