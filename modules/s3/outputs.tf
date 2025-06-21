# S3 Storage Module Outputs - White Label Ready

output "bucket_id" {
  description = "ID of the S3 storage bucket"
  value       = aws_s3_bucket.storage.id
}

output "bucket_arn" {
  description = "ARN of the S3 storage bucket"
  value       = aws_s3_bucket.storage.arn
}

output "bucket_domain_name" {
  description = "Domain name of the S3 storage bucket"
  value       = aws_s3_bucket.storage.bucket_domain_name
}

output "bucket_regional_domain_name" {
  description = "Regional domain name of the S3 storage bucket"
  value       = aws_s3_bucket.storage.bucket_regional_domain_name
}

output "bucket_name" {
  description = "Name of the S3 storage bucket"
  value       = aws_s3_bucket.storage.bucket
}

# IAM Role Outputs
output "storage_access_role_arn" {
  description = "ARN of the IAM role for storage access"
  value       = aws_iam_role.s3_storage_access_role.arn
}

output "storage_access_role_name" {
  description = "Name of the IAM role for storage access"
  value       = aws_iam_role.s3_storage_access_role.name
}

output "instance_profile_arn" {
  description = "ARN of the IAM instance profile"
  value       = aws_iam_instance_profile.s3_storage_access_profile.arn
}

output "instance_profile_name" {
  description = "Name of the IAM instance profile"
  value       = aws_iam_instance_profile.s3_storage_access_profile.name
}

output "readonly_role_arn" {
  description = "ARN of the read-only IAM role (if created)"
  value       = var.create_read_only_role ? aws_iam_role.s3_readonly_role[0].arn : null
}

output "admin_role_arn" {
  description = "ARN of the admin IAM role (if created)"
  value       = var.create_admin_role ? aws_iam_role.s3_admin_role[0].arn : null
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group for S3 access logs"
  value       = var.enable_access_logging ? aws_cloudwatch_log_group.s3_access_logs[0].name : null
}

output "cloudwatch_log_group_arn" {
  description = "ARN of the CloudWatch log group for S3 access logs"
  value       = var.enable_access_logging ? aws_cloudwatch_log_group.s3_access_logs[0].arn : null
}

# Configuration Information for Consumers
output "partition_format" {
  description = "Partition format used for Athena queries"
  value       = var.partition_format
}

output "primary_data_prefix" {
  description = "Primary prefix for data objects with intelligent tiering"
  value       = var.primary_data_prefix
}

output "secondary_data_prefixes" {
  description = "Secondary prefixes for data objects"
  value       = var.secondary_data_prefixes
}

output "temp_prefixes" {
  description = "Map of temporary data prefixes and expiration settings"
  value       = var.temp_prefixes
}

output "use_case" {
  description = "Use case this storage bucket is configured for"
  value       = var.use_case
}

# Usage Examples and Documentation
output "athena_partition_example" {
  description = "Example of how to structure data for Athena partitioning"
  value = {
    primary_data_path     = "s3://${aws_s3_bucket.storage.id}/${var.primary_data_prefix}year=${formatdate("YYYY", timestamp())}/month=${formatdate("MM", timestamp())}/day=${formatdate("DD", timestamp())}/hour=14/data.json"
    processed_path        = "s3://${aws_s3_bucket.storage.id}/processed/year=${formatdate("YYYY", timestamp())}/month=${formatdate("MM", timestamp())}/day=${formatdate("DD", timestamp())}/hour=14/processed.parquet"
    partition_query       = "PARTITION (year=${formatdate("YYYY", timestamp())}, month=${formatdate("MM", timestamp())}, day=${formatdate("DD", timestamp())}, hour=14)"
    athena_table_location = "s3://${aws_s3_bucket.storage.id}/${var.primary_data_prefix}"
    bucket_uri           = "s3://${aws_s3_bucket.storage.id}/"
  }
}

output "integration_examples" {
  description = "Examples for integrating with the storage bucket"
  value = {
    aws_cli_upload = "aws s3 cp file.json s3://${aws_s3_bucket.storage.id}/${var.primary_data_prefix}year=$$YEAR/month=$$MONTH/day=$$DAY/hour=$$HOUR/"
    boto3_upload   = "s3.put_object(Bucket='${aws_s3_bucket.storage.id}', Key='${var.primary_data_prefix}year=${formatdate("YYYY", timestamp())}/month=${formatdate("MM", timestamp())}/day=${formatdate("DD", timestamp())}/hour=14/data.json', Body=data)"
    role_arn       = aws_iam_role.s3_storage_access_role.arn
  }
}

output "cost_optimization_features" {
  description = "Summary of cost optimization features enabled"
  value = {
    intelligent_tiering_enabled = var.enable_intelligent_tiering
    lifecycle_policy_enabled   = var.enable_lifecycle_policy
    versioning_enabled         = var.versioning_enabled
    transitions_configured     = length(var.lifecycle_transitions)
    archive_after_days        = var.enable_intelligent_tiering && length(var.tiering_configurations) > 0 ? var.tiering_configurations[0].days : null
    deep_archive_after_days   = var.enable_intelligent_tiering && length(var.tiering_configurations) > 1 ? var.tiering_configurations[1].days : null
    temp_prefixes_count       = length(var.temp_prefixes)
    secondary_prefixes_count  = length(var.secondary_data_prefixes)
  }
}

output "white_label_configuration" {
  description = "White label configuration summary"
  value = {
    instance_name      = var.instance_name
    bucket_name_suffix = var.bucket_name_suffix
    use_case          = var.use_case
    module_version    = "white-label-ready"
    multi_tenant_ready = length(var.secondary_data_prefixes) > 0
    cross_account_ready = length(var.trusted_accounts) > 0
  }
}