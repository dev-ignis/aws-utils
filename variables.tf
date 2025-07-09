##############################
# General AWS & Infrastructure
##############################
variable "region" {
  type    = string
  default = "us-west-2"
}

variable "ami" {
  description = "The AMI to use for the EC2 instance"
  type        = string
}

variable "instance_type" {
  description = "The EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "instance_count" {
  description = "Number of EC2 instances to deploy"
  type        = number
  default     = 2
  
  validation {
    condition     = var.instance_count >= 2 && var.instance_count <= 10
    error_message = "Instance count must be between 2 and 10 for high availability."
  }
}

variable "instance_name" {
  description = "Name tag for the EC2 instance"
  type        = string
}

variable "key_name" {
  description = "The key pair to use for SSH access"
  type        = string
}

variable "dns_name" {
  description = "The DNS record name to assign to the instance"
  type        = string
  default     = ""
}

variable "blue_green_enabled" {
  description = "Enable blue-green deployment instead of rolling deployment"
  type        = bool
  default     = false
}

variable "active_target_group" {
  description = "Currently active target group (blue or green)"
  type        = string
  default     = "blue"
  validation {
    condition     = contains(["blue", "green"], var.active_target_group)
    error_message = "Active target group must be either 'blue' or 'green'."
  }
}

variable "enable_rollback" {
  description = "Enable automatic rollback on deployment failure"
  type        = bool
  default     = true
}

variable "rollback_timeout_minutes" {
  description = "Timeout in minutes before triggering rollback"
  type        = number
  default     = 5
}

variable "skip_deployment_validation" {
  description = "Skip the 15-minute validation process for faster Terraform runs"
  type        = bool
  default     = false
}

variable "discord_webhook_url" {
  description = "Discord webhook URL for deployment notifications"
  type        = string
  default     = ""
  sensitive   = true
}

variable "enable_discord_notifications" {
  description = "Enable Discord notifications for deployments"
  type        = bool
  default     = false
}

variable "certbot_email" {
  description = "Email to use for Certbot to obtain SSL certificates"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the custom VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidrs" {
  description = "List of CIDR blocks for the subnets (at least two)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "availability_zones" {
  description = "List of availability zones for the subnets (at least two)"
  type        = list(string)
  default     = ["us-west-2a", "us-west-2b"]
}

variable "enable_load_balancer" {
  description = "Enable or disable the load balancer"
  type        = bool
  default     = false
}

variable "skip_route53" {
  description = "Skip creating Route53 DNS records if true (e.g., in CI)"
  type        = bool
  default     = false
}

variable "environment" {
  description = "The environment in which resources are deployed (e.g., dev, staging, prod)"
  type        = string
}

##############################
# Route53 & Hosted Zone
##############################
variable "route53_zone_id" {
  description = "The ID of the Route53 hosted zone"
  type        = string
}

variable "staging_api_dns_name" {
  description = "DNS name for the staging API endpoint"
  type        = string
  default     = ""
}

variable "prod_api_dns_name" {
  description = "DNS name for the production API endpoint"
  type        = string
  default     = ""
}

variable "create_hosted_zone" {
  description = "Whether to create a new Route53 hosted zone if not already available"
  type        = bool
  default     = false
}

variable "hosted_zone_name" {
  description = "The name of the hosted zone to create (e.g., amygdalas.com)"
  type        = string
  default     = ""
}

variable "create_apex_record" {
  description = "Whether to create an A record for the apex/root domain"
  type        = bool
  default     = true
}

variable "create_mail_records" {
  description = "Whether to create email-related DNS records (MX, SPF, DKIM, DMARC)"
  type        = bool
  default     = false
}

variable "mx_records" {
  description = "List of MX records for the domain (e.g., ['10 mail.example.com', '20 mail2.example.com'])"
  type        = list(string)
  default     = []
}

variable "spf_record" {
  description = "SPF record value (e.g., 'include:_spf.google.com include:amazonses.com ~all')"
  type        = string
  default     = "include:_spf.google.com"
}

variable "dkim_records" {
  description = "List of DKIM TXT record values"
  type        = list(string)
  default     = []
}

variable "dkim_selector" {
  description = "DKIM selector name (e.g., 'google' for Google Workspace)"
  type        = string
  default     = "default"
}

variable "dmarc_policy" {
  description = "DMARC policy (none, quarantine, or reject)"
  type        = string
  default     = "none"
}

variable "dmarc_email" {
  description = "Email address to receive DMARC reports"
  type        = string
  default     = "admin@example.com"
}

variable "create_wildcard_record" {
  description = "Whether to create a wildcard record for the domain"
  type        = bool
  default     = false
}

variable "custom_dns_records" {
  description = "Map of custom DNS records to create (CNAME, TXT, A, etc.)"
  type = map(object({
    type    = string
    ttl     = number
    records = list(string)
  }))
  default = {}
}

variable "cname_records" {
  description = "Map of CNAME records to create. Key is the subdomain, value is the target."
  type        = map(string)
  default     = {}
}

variable "txt_records" {
  description = "Map of TXT records to create. Key is the subdomain (use @ for root), value is list of TXT values."
  type        = map(list(string))
  default     = {}
}

##############################
# SSH & Remote Backend Settings
##############################
variable "ssh_private_key_path" {
  description = "Path to the SSH private key used for connecting to EC2 instances"
  type        = string
  default     = "~/.ssh/id_rsa_github"
}

# Remote backend variables (if used) can be defined here.
# For example:
# variable "backend_bucket" { ... }
# variable "backend_key" { ... }
# variable "backend_region" { ... }
# variable "backend_encrypt" { ... }
# variable "backend_dynamodb_table" { ... }

##############################
# Docker & Application Variables
##############################

# New backend app configuration
variable "backend_image" {
  description = "Docker image for the backend app (e.g., Go Gin app)"
  type        = string
  default     = "rollg/go-gin-app"
}

variable "backend_container_name" {
  description = "Container name for the backend app"
  type        = string
  default     = "backend_app"
}

variable "backend_port" {
  description = "Port on which the backend app listens"
  type        = string
  default     = "8080"
}

variable "front_end_image" {
  description = "Docker image for the front-end app"
  type        = string
}

variable "front_end_container_name" {
  description = "Container name for the front-end app"
  type        = string
  default     = "front_end_app"
}

variable "front_end_port" {
  description = "Port on which the front-end app listens"
  type        = string
  default     = "3000"
}

variable "next_resend_api_key" {
  description = "The API key for Next Resend"
  type        = string
}

##############################
# S3 Storage Variables - White Label Ready
##############################

variable "s3_bucket_name_suffix" {
  description = "Suffix for the S3 bucket name (e.g., 'data-lake', 'analytics', 'storage')"
  type        = string
  default     = "data-collection"
}

variable "s3_use_case" {
  description = "Use case description for S3 storage (e.g., 'analytics', 'data-lake', 'backup')"
  type        = string
  default     = "data-analytics"
}

variable "s3_primary_data_prefix" {
  description = "Primary prefix for data objects in S3 bucket"
  type        = string
  default     = "data/"
}

variable "s3_secondary_data_prefixes" {
  description = "Additional prefixes for multi-tenant or multi-purpose buckets"
  type        = list(string)
  default     = []
}

variable "enable_s3_intelligent_tiering" {
  description = "Enable S3 Intelligent Tiering for cost optimization"
  type        = bool
  default     = true
}

variable "enable_s3_lifecycle_policy" {
  description = "Enable S3 lifecycle policy for cost optimization"
  type        = bool
  default     = true
}

variable "s3_lifecycle_transitions" {
  description = "List of S3 lifecycle transition rules"
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

variable "s3_versioning_enabled" {
  description = "Enable S3 bucket versioning"
  type        = bool
  default     = true
}

variable "s3_kms_key_id" {
  description = "KMS key ID for S3 encryption (optional)"
  type        = string
  default     = null
}

variable "s3_trusted_accounts" {
  description = "List of AWS account IDs for cross-account S3 access"
  type        = list(string)
  default     = []
}

variable "create_s3_read_only_role" {
  description = "Create an additional read-only IAM role for analytics/reporting"
  type        = bool
  default     = false
}

variable "create_s3_admin_role" {
  description = "Create an administrative IAM role with full bucket access"
  type        = bool
  default     = false
}

variable "s3_temp_prefixes" {
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

variable "setup_s3_athena_partitions" {
  description = "Create partition structure for Athena queries"
  type        = bool
  default     = true
}

variable "enable_s3_access_logging" {
  description = "Enable CloudWatch access logging for S3"
  type        = bool
  default     = true
}

variable "s3_log_retention_days" {
  description = "S3 CloudWatch log retention period in days"
  type        = number
  default     = 30
}

variable "create_s3_partition_examples" {
  description = "Create S3 partition structure examples for Athena queries"
  type        = bool
  default     = true
}

##############################
# SQS Processing Variables - White Label Ready
##############################

variable "sqs_use_case" {
  description = "Use case description for SQS queues (e.g., 'api-processing', 'data-pipeline', 'notifications')"
  type        = string
  default     = "api-processing"
}

variable "sqs_queue_configurations" {
  description = "Map of SQS queue configurations"
  type = map(object({
    fifo_queue                    = bool
    content_based_deduplication   = bool
    description                   = string
    message_retention_seconds     = number
    visibility_timeout_seconds    = number
    max_message_size             = number
    delay_seconds                = number
    receive_wait_time_seconds    = number
    enable_dlq                   = bool
    max_receive_count           = number
    alarm_max_depth             = number
  }))
  default = {
    feedback = {
      fifo_queue                  = true
      content_based_deduplication = false
      description                 = "User feedback processing queue"
      message_retention_seconds   = 1209600
      visibility_timeout_seconds  = 300
      max_message_size           = 262144
      delay_seconds              = 0
      receive_wait_time_seconds  = 20
      enable_dlq                 = true
      max_receive_count          = 3
      alarm_max_depth            = 100
    }
    emails = {
      fifo_queue                  = true
      content_based_deduplication = false
      description                 = "Email campaign processing queue"
      message_retention_seconds   = 1209600
      visibility_timeout_seconds  = 600
      max_message_size           = 262144
      delay_seconds              = 0
      receive_wait_time_seconds  = 20
      enable_dlq                 = true
      max_receive_count          = 3
      alarm_max_depth            = 500
    }
    analytics = {
      fifo_queue                  = true
      content_based_deduplication = true
      description                 = "Analytics events processing queue"
      message_retention_seconds   = 604800
      visibility_timeout_seconds  = 120
      max_message_size           = 262144
      delay_seconds              = 0
      receive_wait_time_seconds  = 20
      enable_dlq                 = true
      max_receive_count          = 3
      alarm_max_depth            = 1000
    }
    testflight = {
      fifo_queue                  = true
      content_based_deduplication = false
      description                 = "TestFlight invitation processing queue"
      message_retention_seconds   = 1209600
      visibility_timeout_seconds  = 300
      max_message_size           = 262144
      delay_seconds              = 0
      receive_wait_time_seconds  = 20
      enable_dlq                 = true
      max_receive_count          = 3
      alarm_max_depth            = 50
    }
  }
}

variable "sqs_environment_overrides" {
  description = "Environment-specific SQS queue configuration overrides"
  type = map(object({
    message_retention_seconds  = optional(number)
    visibility_timeout_seconds = optional(number)
    max_receive_count         = optional(number)
    alarm_max_depth          = optional(number)
  }))
  default = {
    staging = {
      message_retention_seconds  = 604800
      visibility_timeout_seconds = 60
      max_receive_count         = 2
      alarm_max_depth          = 50
    }
  }
}

variable "enable_sqs_encryption" {
  description = "Enable SQS encryption using KMS"
  type        = bool
  default     = true
}

variable "sqs_kms_key_id" {
  description = "KMS key ID for SQS encryption (null for AWS managed key)"
  type        = string
  default     = null
}

variable "create_sqs_api_role" {
  description = "Create IAM role for API services to send SQS messages"
  type        = bool
  default     = true
}

variable "create_sqs_worker_role" {
  description = "Create IAM role for worker services to process SQS messages"
  type        = bool
  default     = true
}

variable "create_sqs_instance_profiles" {
  description = "Create EC2 instance profiles for SQS IAM roles"
  type        = bool
  default     = true
}

variable "enable_sqs_cloudwatch_alarms" {
  description = "Enable CloudWatch alarms for SQS queue monitoring"
  type        = bool
  default     = true
}

variable "sqs_cloudwatch_alarm_actions" {
  description = "List of ARNs to notify when SQS CloudWatch alarms trigger"
  type        = list(string)
  default     = []
}

variable "enable_sqs_operations_logging" {
  description = "Enable CloudWatch logging for SQS operations"
  type        = bool
  default     = true
}

variable "sqs_log_retention_days" {
  description = "SQS CloudWatch log retention period in days"
  type        = number
  default     = 30
}

variable "enable_sqs_s3_integration" {
  description = "Enable IAM permissions for SQS-S3 integration"
  type        = bool
  default     = true
}

variable "enable_sqs_multi_tenant" {
  description = "Enable multi-tenant SQS queue configurations"
  type        = bool
  default     = false
}

variable "sqs_tenant_configurations" {
  description = "Tenant-specific SQS queue configurations for multi-tenant setups"
  type = map(object({
    queue_name_prefix = string
    custom_tags       = map(string)
  }))
  default = {}
}

variable "enable_sqs_cost_allocation_tags" {
  description = "Enable detailed cost allocation tags for SQS"
  type        = bool
  default     = true
}

variable "sqs_cost_center" {
  description = "Cost center for SQS billing allocation"
  type        = string
  default     = ""
}

variable "sqs_project_code" {
  description = "Project code for SQS cost tracking"
  type        = string
  default     = ""
}

##############################
# Feedback API Variables
##############################

variable "enable_feedback_api" {
  description = "Enable feedback API endpoints"
  type        = bool
  default     = false
}

variable "feedback_max_upload_size_mb" {
  description = "Maximum upload size for feedback screenshots in MB"
  type        = number
  default     = 10
}

variable "feedback_rate_limit_per_minute" {
  description = "Rate limit for feedback submissions per minute"
  type        = number
  default     = 10
}

variable "enable_zendesk_integration" {
  description = "Enable Zendesk integration for feedback processing"
  type        = bool
  default     = false
}

variable "api_rate_limit_enabled" {
  description = "Enable API rate limiting"
  type        = bool
  default     = false
}

variable "api_rate_limit_requests_per_minute" {
  description = "API rate limit requests per minute"
  type        = number
  default     = 100
}

variable "api_timeout_seconds" {
  description = "API request timeout in seconds"
  type        = number
  default     = 30
}

variable "api_max_request_size_mb" {
  description = "Maximum API request size in MB"
  type        = number
  default     = 20
}

variable "feedback_processing_timeout" {
  description = "Timeout for processing feedback in seconds"
  type        = number
  default     = 300
}

variable "feedback_screenshot_compression" {
  description = "Screenshot compression quality (0-1)"
  type        = number
  default     = 0.8
}

variable "enable_feedback_notifications" {
  description = "Enable notifications for feedback submissions"
  type        = bool
  default     = true
}

variable "feedback_queue_batch_size" {
  description = "Batch size for processing feedback queue"
  type        = number
  default     = 10
}

variable "feedback_dlq_retry_delay" {
  description = "Delay before retrying failed feedback messages (seconds)"
  type        = number
  default     = 300
}

variable "feedback_queue_alarm_threshold" {
  description = "Alarm threshold for feedback queue depth"
  type        = number
  default     = 50
}

variable "feedback_upload_failure_threshold" {
  description = "Alarm threshold for upload failures"
  type        = number
  default     = 5
}

variable "feedback_processing_error_threshold" {
  description = "Alarm threshold for processing errors"
  type        = number
  default     = 10
}

variable "dynamodb_feedback_table_name" {
  description = "Name of the feedback DynamoDB table"
  type        = string
  default     = ""
}

variable "dynamodb_feedback_billing_mode" {
  description = "Billing mode for feedback DynamoDB table"
  type        = string
  default     = "PAY_PER_REQUEST"
}

variable "dynamodb_feedback_hash_key" {
  description = "Hash key for feedback DynamoDB table"
  type        = string
  default     = "id"
}

variable "dynamodb_feedback_range_key" {
  description = "Range key for feedback DynamoDB table"
  type        = string
  default     = "created_at"
}

variable "create_app_user_access_key" {
  description = "Whether to create access key for app_user"
  type        = bool
  default     = false
}

