provider "aws" {
  region = var.region
  
  # Default tags applied to ALL resources
  default_tags {
    tags = {
      Environment   = var.environment
      Project       = "MHT-API"
      ManagedBy     = "terraform"
      Repository    = "aws-docker-deployment"
      CostCenter    = var.environment == "production" ? "production" : "development"
    }
  }
}

module "network" {
  source             = "./modules/network"
  instance_name      = var.instance_name
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  subnet_cidrs       = var.subnet_cidrs
  availability_zones = var.availability_zones
  backend_port       = var.backend_port
}

module "dynamodb" {
  source        = "./modules/dynamodb"
  table_name    = "${var.instance_name}-${var.environment}-table"
  billing_mode  = "PAY_PER_REQUEST"
  hash_key      = "Id"
  hash_key_type = "S"
  
  # Additional attributes for user table GSIs
  additional_attributes = [
    { name = "Email", type = "S" },
    { name = "AppleId", type = "S" }
  ]
  
  # GSIs for user authentication
  global_secondary_indexes = [
    {
      name            = "email-index"
      hash_key        = "Email"
      projection_type = "ALL"
    },
    {
      name            = "apple_id-index"
      hash_key        = "AppleId"
      projection_type = "ALL"
    }
  ]
  
  tags = {
    Environment = var.environment
    Name        = "${var.instance_name}-${var.environment}-dynamodb"
  }
}

# DynamoDB table for feedback storage
module "dynamodb_feedback" {
  source = "./modules/dynamodb"
  
  table_name     = "${var.instance_name}-${var.environment}-feedback"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"
  hash_key_type  = "S"
  range_key      = "created_at"
  range_key_type = "S"
  
  # Additional attributes for feedback table GSIs
  additional_attributes = [
    { name = "device_id", type = "S" }
  ]
  
  # GSI for querying feedback by device
  global_secondary_indexes = [
    {
      name            = "DeviceIdIndex"
      hash_key        = "device_id"
      range_key       = "created_at"
      projection_type = "ALL"
    }
  ]
  
  tags = {
    Environment = var.environment
    Name        = "${var.instance_name}-${var.environment}-feedback-table"
    Purpose     = "Feedback and bug reports storage"
    Module      = "feedback-api"
  }
}

# CloudWatch Monitoring Module
module "cloudwatch_monitoring" {
  source = "./modules/cloudwatch"
  
  instance_name = var.instance_name
  environment   = var.environment
  region        = var.region
  alb_arn_suffix = var.enable_load_balancer && length(module.alb) > 0 ? module.alb[0].alb_arn_suffix : ""
  
  # Custom namespace for beta metrics
  custom_namespace = var.cloudwatch_custom_namespace
  
  # Feature flags (different for staging/production)
  enable_cloudwatch_dashboard = var.enable_cloudwatch_dashboard
  enable_cloudwatch_alarms    = var.enable_cloudwatch_alarms
  enable_sns_alerts          = var.enable_sns_alerts
  enable_slack_alerts        = var.enable_slack_alerts
  track_engagement_metrics   = var.track_engagement_metrics
  
  # Alert configuration
  alert_email       = var.cloudwatch_alert_email
  slack_webhook_url = var.slack_webhook_url
  
  # Alarm thresholds (can be different for staging/production)
  error_rate_threshold          = var.cloudwatch_error_rate_threshold
  error_rate_evaluation_periods = var.cloudwatch_error_rate_evaluation_periods
  response_time_threshold       = var.cloudwatch_response_time_threshold
  engagement_threshold          = var.cloudwatch_engagement_threshold
  engagement_evaluation_periods = var.cloudwatch_engagement_evaluation_periods
  
  # Cost optimization
  enable_detailed_monitoring = var.enable_detailed_monitoring
}

# Create EC2 instances distributed across subnets
resource "aws_instance" "my_ec2" {
  count                  = var.instance_count
  ami                    = var.ami
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = module.network.lb_subnet_ids[count.index % length(module.network.lb_subnet_ids)]
  vpc_security_group_ids = [module.network.instance_security_group_id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  user_data = templatefile("${path.module}/user_data.sh.tpl", {
    backend_image            = var.backend_image
    front_end_image          = var.front_end_image
    backend_container_name   = var.backend_container_name
    front_end_container_name = var.front_end_container_name
    backend_port             = var.backend_port
    front_end_port           = var.front_end_port
    dns_name                 = var.dns_name
    certbot_email            = var.certbot_email
    region                   = var.region
    environment              = var.environment
    instance_name            = var.instance_name
    next_resend_api_key      = var.next_resend_api_key
    # Feedback API variables
    feedback_table_name      = module.dynamodb_feedback.table_name
    s3_bucket_name          = module.s3_storage.bucket_name
    feedback_queue_url      = module.sqs_processing.queue_urls["feedback"]
    analytics_queue_url     = module.sqs_processing.queue_urls["analytics"]
    enable_feedback_api     = var.enable_feedback_api
    feedback_max_upload_size_mb = var.feedback_max_upload_size_mb
    feedback_rate_limit_per_minute = var.feedback_rate_limit_per_minute
    enable_zendesk_integration = var.enable_zendesk_integration
    api_rate_limit_enabled  = var.api_rate_limit_enabled
    api_rate_limit_requests_per_minute = var.api_rate_limit_requests_per_minute
    api_timeout_seconds     = var.api_timeout_seconds
    api_max_request_size_mb = var.api_max_request_size_mb
    # Nginx configuration
    nginx_max_body_size     = var.nginx_max_body_size
  })

  tags = {
    Name        = "${var.instance_name}-${var.environment}-${count.index}"
    Environment = var.environment
    Instance    = "${count.index + 1}"
    Module      = "compute"
    Owner       = var.instance_name
  }

  lifecycle {
    ignore_changes = [user_data]
  }
}

# Pass required values to the ALB module, including the staging DNS name.
module "s3_storage" {
  source = "./modules/s3"
  
  instance_name      = var.instance_name
  bucket_name_suffix = var.s3_bucket_name_suffix
  use_case          = var.s3_use_case
  environment       = var.environment
  
  tags = {
    Environment = var.environment
    Project     = "Amygdalas"
    Purpose     = var.s3_use_case
    Owner       = var.instance_name
  }
  
  # Data Organization
  primary_data_prefix      = var.s3_primary_data_prefix
  secondary_data_prefixes  = var.s3_secondary_data_prefixes
  
  # Intelligent Tiering Configuration
  enable_intelligent_tiering = var.enable_s3_intelligent_tiering
  
  # Lifecycle Policy Configuration
  enable_lifecycle_policy = var.enable_s3_lifecycle_policy
  lifecycle_transitions   = var.s3_lifecycle_transitions
  
  # Security Configuration
  versioning_enabled = var.s3_versioning_enabled
  kms_key_id        = var.s3_kms_key_id
  trusted_accounts  = var.s3_trusted_accounts
  
  # IAM Configuration
  create_read_only_role = var.create_s3_read_only_role
  create_admin_role     = var.create_s3_admin_role
  
  # Temporary Data Configuration
  temp_prefixes = var.s3_temp_prefixes
  
  # Partition Configuration
  setup_athena_partitions = var.setup_s3_athena_partitions
  
  # Logging Configuration
  enable_access_logging = var.enable_s3_access_logging
  log_retention_days   = var.s3_log_retention_days
}

# Athena Module for S3 Data Analysis
module "athena" {
  source = "./modules/athena"
  
  instance_name = var.instance_name
  environment   = var.environment
  use_case      = var.athena_use_case
  
  tags = {
    Environment = var.environment
    Project     = "Amygdalas"
    Purpose     = var.athena_use_case
    Owner       = var.instance_name
  }
  
  # S3 Data Source Configuration
  s3_data_bucket     = module.s3_storage.bucket_name
  s3_data_bucket_arn = module.s3_storage.bucket_arn
  
  # Athena Configuration
  athena_engine_version         = var.athena_engine_version
  bytes_scanned_cutoff_per_query = var.athena_bytes_scanned_cutoff_per_query
  enable_cloudwatch_metrics     = var.enable_athena_cloudwatch_metrics
  
  # Security Configuration
  kms_key_id            = var.athena_kms_key_id
  expected_bucket_owner = var.athena_expected_bucket_owner
  
  # Results Configuration
  enable_athena_results_lifecycle = var.enable_athena_results_lifecycle
  athena_results_retention_days   = var.athena_results_retention_days
  
  # Query Configuration
  create_sample_queries  = var.create_athena_sample_queries
  create_analytics_views = var.create_athena_analytics_views
  
  # Logging Configuration
  enable_athena_logging     = var.enable_athena_logging
  athena_log_retention_days = var.athena_log_retention_days
  
  # Cost Control Configuration
  enable_cost_alerts         = var.enable_athena_cost_alerts
  cost_alert_threshold_bytes = var.athena_cost_alert_threshold_bytes
  alarm_actions             = var.athena_alarm_actions
  
  # Partition Configuration
  partition_projection_enabled = var.athena_partition_projection_enabled
  partition_projection_range   = var.athena_partition_projection_range
  
  # Data Format Configuration
  data_format        = var.athena_data_format
  compression_format = var.athena_compression_format
  
  # Table Configuration
  enable_analytics_table     = var.enable_athena_analytics_table
  enable_user_behavior_table = var.enable_athena_user_behavior_table
  enable_feedback_table      = var.enable_athena_feedback_table
  enable_transactions_table  = var.enable_athena_transactions_table
  
  # Performance Configuration
  enable_columnar_storage   = var.enable_athena_columnar_storage
  enable_data_partitioning = var.enable_athena_data_partitioning
}

module "sqs_processing" {
  source = "./modules/sqs"
  
  instance_name = var.instance_name
  use_case     = var.sqs_use_case
  environment  = var.environment
  
  tags = {
    Environment = var.environment
    Project     = "Amygdalas"
    Purpose     = var.sqs_use_case
    Owner       = var.instance_name
  }
  
  # Queue Configuration
  queue_configurations = var.sqs_queue_configurations
  
  # Environment-specific overrides
  environment_specific_overrides = var.sqs_environment_overrides
  
  # Encryption Configuration
  enable_encryption = var.enable_sqs_encryption
  kms_key_id       = var.sqs_kms_key_id
  
  # IAM Configuration
  create_api_service_role    = var.create_sqs_api_role
  create_worker_service_role = var.create_sqs_worker_role
  create_instance_profiles   = var.create_sqs_instance_profiles
  
  # CloudWatch Configuration
  enable_cloudwatch_alarms = var.enable_sqs_cloudwatch_alarms
  cloudwatch_alarm_actions = var.sqs_cloudwatch_alarm_actions
  enable_operations_logging = var.enable_sqs_operations_logging
  log_retention_days       = var.sqs_log_retention_days
  
  # S3 Integration
  s3_bucket_arn        = module.s3_storage.bucket_arn
  enable_s3_integration = var.enable_sqs_s3_integration
  
  # Multi-tenant Configuration
  enable_multi_tenant_queues = var.enable_sqs_multi_tenant
  tenant_configurations      = var.sqs_tenant_configurations
  
  # Cost Optimization
  enable_cost_allocation_tags = var.enable_sqs_cost_allocation_tags
  cost_center                = var.sqs_cost_center
  project_code              = var.sqs_project_code
}

module "alb" {
  source               = "./modules/alb"
  count                = var.enable_load_balancer ? 1 : 0
  instance_name        = var.instance_name
  app_port             = var.backend_port
  vpc_id               = module.network.vpc_id
  lb_subnet_ids        = module.network.lb_subnet_ids
  security_group_id    = module.network.alb_security_group_id
  instance_ids         = aws_instance.my_ec2[*].id
  staging_api_dns_name = var.staging_api_dns_name
  domain_name          = var.hosted_zone_name
  environment          = var.environment
  route53_zone_id      = var.route53_zone_id
  skip_route53          = var.skip_route53
  blue_green_enabled   = var.blue_green_enabled
  active_target_group  = var.active_target_group
}
