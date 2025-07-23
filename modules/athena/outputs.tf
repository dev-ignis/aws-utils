# Athena Module Outputs

# Database
output "database_name" {
  description = "Name of the Athena database"
  value       = aws_athena_database.main.name
}

output "database_bucket" {
  description = "S3 bucket for Athena database"
  value       = aws_athena_database.main.bucket
}

# Workgroup
output "workgroup_name" {
  description = "Name of the Athena workgroup"
  value       = aws_athena_workgroup.main.name
}

output "workgroup_arn" {
  description = "ARN of the Athena workgroup"
  value       = aws_athena_workgroup.main.arn
}

# S3 Buckets
output "athena_results_bucket" {
  description = "S3 bucket for Athena query results"
  value       = aws_s3_bucket.athena_results.bucket
}

output "athena_results_bucket_arn" {
  description = "ARN of the Athena results bucket"
  value       = aws_s3_bucket.athena_results.arn
}

# IAM Role
output "athena_role_arn" {
  description = "ARN of the Athena service role"
  value       = aws_iam_role.athena_role.arn
}

output "athena_role_name" {
  description = "Name of the Athena service role"
  value       = aws_iam_role.athena_role.name
}

# Named Queries
output "create_tables_queries" {
  description = "Named queries for creating tables"
  value = {
    analytics_table     = aws_athena_named_query.create_analytics_table.name
    user_behavior_table = aws_athena_named_query.create_user_behavior_table.name
    feedback_table      = aws_athena_named_query.create_feedback_table.name
    transactions_table  = aws_athena_named_query.create_transactions_table.name
  }
}

output "sample_queries" {
  description = "Sample analytics queries"
  value = var.create_sample_queries ? {
    for query in aws_athena_named_query.sample_queries : query.name => query.query
  } : {}
}

# CloudWatch
output "athena_log_group" {
  description = "CloudWatch log group for Athena"
  value       = var.enable_athena_logging ? aws_cloudwatch_log_group.athena_logs[0].name : null
}

output "cost_alarm_name" {
  description = "CloudWatch alarm for high query costs"
  value       = var.enable_cost_alerts ? aws_cloudwatch_metric_alarm.high_query_costs[0].alarm_name : null
}

# Configuration
output "athena_config" {
  description = "Athena configuration summary"
  value = {
    database_name      = aws_athena_database.main.name
    workgroup_name     = aws_athena_workgroup.main.name
    results_bucket     = aws_s3_bucket.athena_results.bucket
    engine_version     = var.athena_engine_version
    cost_limit_gb      = var.bytes_scanned_cutoff_per_query / 1073741824
    results_retention  = var.athena_results_retention_days
  }
}

# Query URLs (for easy access in AWS Console)
output "athena_console_urls" {
  description = "URLs for accessing Athena in AWS Console"
  value = {
    workgroup_url = "https://console.aws.amazon.com/athena/home?region=${data.aws_region.current.name}#workgroups/${aws_athena_workgroup.main.name}"
    database_url  = "https://console.aws.amazon.com/athena/home?region=${data.aws_region.current.name}#databases/${aws_athena_database.main.name}"
    queries_url   = "https://console.aws.amazon.com/athena/home?region=${data.aws_region.current.name}#queries/saved"
  }
}

# Data source for current region
data "aws_region" "current" {}