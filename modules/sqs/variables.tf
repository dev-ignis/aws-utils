# White Label SQS Module Variables

variable "instance_name" {
  description = "Name of the instance/application for resource naming"
  type        = string
}

variable "use_case" {
  description = "Use case description for SQS queues (e.g., 'api-processing', 'data-pipeline', 'notifications')"
  type        = string
  default     = "api-processing"
}

variable "tags" {
  description = "A map of tags to assign to all resources"
  type        = map(string)
  default     = {}
}

# Queue Configuration
variable "queue_configurations" {
  description = "Map of queue configurations"
  type = map(object({
    # Basic queue settings
    fifo_queue                    = bool
    content_based_deduplication   = bool
    description                   = string
    
    # Message settings
    message_retention_seconds     = number
    visibility_timeout_seconds    = number
    max_message_size             = number
    delay_seconds                = number
    receive_wait_time_seconds    = number
    
    # Dead letter queue settings
    enable_dlq                   = bool
    max_receive_count           = number
    
    # CloudWatch alarm settings
    alarm_max_depth             = number
  }))
  
  default = {
    feedback = {
      fifo_queue                  = true
      content_based_deduplication = false
      description                 = "User feedback processing queue"
      message_retention_seconds   = 1209600  # 14 days
      visibility_timeout_seconds  = 300      # 5 minutes
      max_message_size           = 262144    # 256 KB
      delay_seconds              = 0
      receive_wait_time_seconds  = 20        # Long polling
      enable_dlq                 = true
      max_receive_count          = 3
      alarm_max_depth            = 100
    }
    emails = {
      fifo_queue                  = true
      content_based_deduplication = false
      description                 = "Email campaign processing queue"
      message_retention_seconds   = 1209600  # 14 days
      visibility_timeout_seconds  = 600      # 10 minutes
      max_message_size           = 262144    # 256 KB
      delay_seconds              = 0
      receive_wait_time_seconds  = 20        # Long polling
      enable_dlq                 = true
      max_receive_count          = 3
      alarm_max_depth            = 500
    }
    analytics = {
      fifo_queue                  = true
      content_based_deduplication = true
      description                 = "Analytics events processing queue"
      message_retention_seconds   = 604800   # 7 days
      visibility_timeout_seconds  = 120      # 2 minutes
      max_message_size           = 262144    # 256 KB
      delay_seconds              = 0
      receive_wait_time_seconds  = 20        # Long polling
      enable_dlq                 = true
      max_receive_count          = 3
      alarm_max_depth            = 1000
    }
    testflight = {
      fifo_queue                  = true
      content_based_deduplication = false
      description                 = "TestFlight invitation processing queue"
      message_retention_seconds   = 1209600  # 14 days
      visibility_timeout_seconds  = 300      # 5 minutes
      max_message_size           = 262144    # 256 KB
      delay_seconds              = 0
      receive_wait_time_seconds  = 20        # Long polling
      enable_dlq                 = true
      max_receive_count          = 3
      alarm_max_depth            = 50
    }
  }
}

# Environment-specific overrides
variable "environment" {
  description = "Environment name (staging, production, etc.)"
  type        = string
  default     = "production"
}

variable "environment_specific_overrides" {
  description = "Environment-specific queue configuration overrides"
  type = map(object({
    message_retention_seconds  = optional(number)
    visibility_timeout_seconds = optional(number)
    max_receive_count         = optional(number)
    alarm_max_depth          = optional(number)
  }))
  default = {
    staging = {
      message_retention_seconds  = 604800  # 7 days for staging
      visibility_timeout_seconds = 60      # Faster retries
      max_receive_count         = 2        # Fewer retries
      alarm_max_depth          = 50       # Lower thresholds
    }
  }
}

# Dead Letter Queue Configuration
variable "dlq_message_retention_seconds" {
  description = "Message retention period for dead letter queues in seconds"
  type        = number
  default     = 1209600  # 14 days
}

# Encryption Configuration
variable "enable_encryption" {
  description = "Enable SQS encryption using KMS"
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "KMS key ID for SQS encryption (null for AWS managed key)"
  type        = string
  default     = null
}

# IAM Configuration
variable "create_api_service_role" {
  description = "Create IAM role for API services to send messages"
  type        = bool
  default     = true
}

variable "create_worker_service_role" {
  description = "Create IAM role for worker services to process messages"
  type        = bool
  default     = true
}

variable "create_instance_profiles" {
  description = "Create EC2 instance profiles for the IAM roles"
  type        = bool
  default     = true
}

variable "trusted_accounts" {
  description = "List of AWS account IDs for cross-account SQS access"
  type        = list(string)
  default     = []
}

# CloudWatch Configuration
variable "enable_cloudwatch_alarms" {
  description = "Enable CloudWatch alarms for queue monitoring"
  type        = bool
  default     = true
}

variable "cloudwatch_alarm_actions" {
  description = "List of ARNs to notify when CloudWatch alarms trigger"
  type        = list(string)
  default     = []
}

variable "enable_operations_logging" {
  description = "Enable CloudWatch logging for SQS operations"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 30
}

# S3 Integration Configuration
variable "s3_bucket_arn" {
  description = "ARN of the S3 bucket for storing processed results"
  type        = string
  default     = ""
}

variable "enable_s3_integration" {
  description = "Enable IAM permissions for S3 integration"
  type        = bool
  default     = false
}

# White Label Configuration
variable "enable_multi_tenant_queues" {
  description = "Enable multi-tenant queue configurations"
  type        = bool
  default     = false
}

variable "tenant_configurations" {
  description = "Tenant-specific queue configurations for multi-tenant setups"
  type = map(object({
    queue_name_prefix = string
    custom_tags       = map(string)
  }))
  default = {}
}

# Cost Optimization
variable "enable_cost_allocation_tags" {
  description = "Enable detailed cost allocation tags"
  type        = bool
  default     = true
}

variable "cost_center" {
  description = "Cost center for billing allocation"
  type        = string
  default     = ""
}

variable "project_code" {
  description = "Project code for cost tracking"
  type        = string
  default     = ""
}