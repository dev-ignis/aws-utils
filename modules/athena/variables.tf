# Athena Module Variables - White Label Ready

# Basic Configuration
variable "instance_name" {
  description = "Name of the instance/application"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., staging, production)"
  type        = string
}

variable "use_case" {
  description = "Use case for the Athena setup"
  type        = string
  default     = "data-analytics"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# S3 Configuration
variable "s3_data_bucket" {
  description = "S3 bucket name where the data is stored"
  type        = string
}

variable "s3_data_bucket_arn" {
  description = "S3 bucket ARN where the data is stored"
  type        = string
}

# Athena Configuration
variable "athena_engine_version" {
  description = "Athena engine version"
  type        = string
  default     = "Athena engine version 3"
}

variable "bytes_scanned_cutoff_per_query" {
  description = "Maximum bytes scanned per query (cost control)"
  type        = number
  default     = 10737418240  # 10 GB
}

variable "enable_cloudwatch_metrics" {
  description = "Enable CloudWatch metrics for Athena"
  type        = bool
  default     = true
}

# Security Configuration
variable "kms_key_id" {
  description = "KMS key ID for encryption (optional)"
  type        = string
  default     = null
}

variable "expected_bucket_owner" {
  description = "Expected bucket owner AWS account ID"
  type        = string
  default     = null
}

# Athena Results Configuration
variable "enable_athena_results_lifecycle" {
  description = "Enable lifecycle policy for Athena results bucket"
  type        = bool
  default     = true
}

variable "athena_results_retention_days" {
  description = "Number of days to retain Athena query results"
  type        = number
  default     = 30
}

# Query Configuration
variable "create_sample_queries" {
  description = "Create sample queries for common analytics"
  type        = bool
  default     = true
}

variable "create_analytics_views" {
  description = "Create pre-aggregated analytics views"
  type        = bool
  default     = true
}

# Logging Configuration
variable "enable_athena_logging" {
  description = "Enable CloudWatch logging for Athena"
  type        = bool
  default     = true
}

variable "athena_log_retention_days" {
  description = "Number of days to retain Athena logs"
  type        = number
  default     = 30
}

# Cost Control Configuration
variable "enable_cost_alerts" {
  description = "Enable cost monitoring alerts"
  type        = bool
  default     = true
}

variable "cost_alert_threshold_bytes" {
  description = "Threshold for cost alerts in bytes scanned"
  type        = number
  default     = 107374182400  # 100 GB
}

variable "alarm_actions" {
  description = "List of ARNs for alarm actions (SNS topics)"
  type        = list(string)
  default     = []
}

# Partition Configuration
variable "partition_projection_enabled" {
  description = "Enable partition projection for tables"
  type        = bool
  default     = true
}

variable "partition_projection_range" {
  description = "Date range for partition projection"
  type        = object({
    start_date = string  # Format: "2025-01-01"
    end_date   = string  # Format: "2026-12-31"
  })
  default = {
    start_date = "2025-01-01"
    end_date   = "2026-12-31"
  }
}

# Data Format Configuration
variable "data_format" {
  description = "Data format for tables (JSON, PARQUET, etc.)"
  type        = string
  default     = "JSON"
}

variable "compression_format" {
  description = "Compression format for data"
  type        = string
  default     = "GZIP"
}

# Table Configuration
variable "enable_analytics_table" {
  description = "Enable analytics events table"
  type        = bool
  default     = true
}

variable "enable_user_behavior_table" {
  description = "Enable user behavior table"
  type        = bool
  default     = true
}

variable "enable_feedback_table" {
  description = "Enable feedback table"
  type        = bool
  default     = true
}

variable "enable_transactions_table" {
  description = "Enable transactions table"
  type        = bool
  default     = false
}

# Performance Configuration
variable "enable_columnar_storage" {
  description = "Enable columnar storage optimization (requires Parquet)"
  type        = bool
  default     = false
}

variable "enable_data_partitioning" {
  description = "Enable data partitioning by date"
  type        = bool
  default     = true
}