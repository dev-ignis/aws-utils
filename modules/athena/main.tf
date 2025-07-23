# Athena Module - White Label Ready
# This module creates Athena resources for querying S3 data with partition projection
# and cost optimization features

# S3 Bucket for Athena Query Results
resource "aws_s3_bucket" "athena_results" {
  bucket = "${var.instance_name}-${var.environment}-athena-results-${random_id.athena_suffix.hex}"

  tags = merge(var.tags, {
    Name        = "${var.instance_name}-athena-results"
    Environment = var.environment
    Purpose     = "Athena query results storage"
    Module      = "athena"
    UseCase     = var.use_case
    Owner       = var.instance_name
  })
}

# Random ID for Athena results bucket
resource "random_id" "athena_suffix" {
  byte_length = 4
}

# S3 Bucket encryption for Athena results
resource "aws_s3_bucket_server_side_encryption_configuration" "athena_results_encryption" {
  bucket = aws_s3_bucket.athena_results.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_id != null ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_id
    }
    bucket_key_enabled = true
  }
}

# S3 Bucket public access block for Athena results
resource "aws_s3_bucket_public_access_block" "athena_results_pab" {
  bucket = aws_s3_bucket.athena_results.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Lifecycle policy for Athena results
resource "aws_s3_bucket_lifecycle_configuration" "athena_results_lifecycle" {
  count  = var.enable_athena_results_lifecycle ? 1 : 0
  bucket = aws_s3_bucket.athena_results.id

  rule {
    id     = "athena-results-lifecycle"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = var.athena_results_retention_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# Athena Database
resource "aws_athena_database" "main" {
  name   = "${var.instance_name}_${var.environment}_${replace(var.use_case, "-", "_")}"
  bucket = aws_s3_bucket.athena_results.id

  dynamic "encryption_configuration" {
    for_each = var.kms_key_id != null ? [1] : []
    content {
      encryption_option = "SSE_KMS"
      kms_key           = var.kms_key_id
    }
  }

  expected_bucket_owner = var.expected_bucket_owner
}

# Athena Workgroup
resource "aws_athena_workgroup" "main" {
  name = "${var.instance_name}-${var.environment}-${var.use_case}"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = var.enable_cloudwatch_metrics

    result_configuration {
      output_location = "s3://${aws_s3_bucket.athena_results.bucket}/queries/"

      dynamic "encryption_configuration" {
        for_each = var.kms_key_id != null ? [1] : []
        content {
          encryption_option     = "SSE_KMS"
          kms_master_key_id    = var.kms_key_id
        }
      }
    }

    bytes_scanned_cutoff_per_query     = var.bytes_scanned_cutoff_per_query
    engine_version {
      selected_engine_version = var.athena_engine_version
    }
  }

  tags = merge(var.tags, {
    Name        = "${var.instance_name}-athena-workgroup"
    Environment = var.environment
    Purpose     = "Athena workgroup for ${var.use_case}"
    Module      = "athena"
    UseCase     = var.use_case
    Owner       = var.instance_name
  })
}

# Analytics Events Table
resource "aws_athena_named_query" "create_analytics_table" {
  name      = "${var.instance_name}_${var.environment}_create_analytics_table"
  database  = aws_athena_database.main.name
  workgroup = aws_athena_workgroup.main.name
  query     = templatefile("${path.module}/queries/create_analytics_table.sql", {
    table_name    = "${var.instance_name}_${var.environment}_analytics"
    s3_location   = "s3://${var.s3_data_bucket}/analytics/"
    database_name = aws_athena_database.main.name
  })

  description = "Creates the analytics events table with partition projection"
}

# User Behavior Table
resource "aws_athena_named_query" "create_user_behavior_table" {
  name      = "${var.instance_name}_${var.environment}_create_user_behavior_table"
  database  = aws_athena_database.main.name
  workgroup = aws_athena_workgroup.main.name
  query     = templatefile("${path.module}/queries/create_user_behavior_table.sql", {
    table_name    = "${var.instance_name}_${var.environment}_user_behavior"
    s3_location   = "s3://${var.s3_data_bucket}/user-behavior/"
    database_name = aws_athena_database.main.name
  })

  description = "Creates the user behavior table with partition projection"
}

# Feedback Table
resource "aws_athena_named_query" "create_feedback_table" {
  name      = "${var.instance_name}_${var.environment}_create_feedback_table"
  database  = aws_athena_database.main.name
  workgroup = aws_athena_workgroup.main.name
  query     = templatefile("${path.module}/queries/create_feedback_table.sql", {
    table_name    = "${var.instance_name}_${var.environment}_feedback"
    s3_location   = "s3://${var.s3_data_bucket}/feedback/"
    database_name = aws_athena_database.main.name
  })

  description = "Creates the feedback table with partition projection"
}

# Transactions Table
resource "aws_athena_named_query" "create_transactions_table" {
  name      = "${var.instance_name}_${var.environment}_create_transactions_table"
  database  = aws_athena_database.main.name
  workgroup = aws_athena_workgroup.main.name
  query     = templatefile("${path.module}/queries/create_transactions_table.sql", {
    table_name    = "${var.instance_name}_${var.environment}_transactions"
    s3_location   = "s3://${var.s3_data_bucket}/transactions/"
    database_name = aws_athena_database.main.name
  })

  description = "Creates the transactions table with partition projection"
}

# Sample Queries for Common Analytics
resource "aws_athena_named_query" "sample_queries" {
  for_each = var.create_sample_queries ? toset([
    "daily_active_users",
    "error_rate_analysis",
    "user_engagement_metrics",
    "feature_usage_stats",
    "performance_metrics"
  ]) : []

  name      = "${var.instance_name}_${var.environment}_${each.key}"
  database  = aws_athena_database.main.name
  workgroup = aws_athena_workgroup.main.name
  query     = file("${path.module}/queries/samples/${each.key}.sql")

  description = "Sample query for ${replace(each.key, "_", " ")}"
}

# Data Processing View (Pre-aggregated metrics)
resource "aws_athena_named_query" "create_daily_metrics_view" {
  count     = var.create_analytics_views ? 1 : 0
  name      = "${var.instance_name}_${var.environment}_create_daily_metrics_view"
  database  = aws_athena_database.main.name
  workgroup = aws_athena_workgroup.main.name
  query     = templatefile("${path.module}/queries/create_daily_metrics_view.sql", {
    view_name     = "${var.instance_name}_${var.environment}_daily_metrics"
    analytics_table = "${var.instance_name}_${var.environment}_analytics"
    database_name = aws_athena_database.main.name
  })

  description = "Creates a view for daily aggregated metrics"
}

# IAM Role for Athena
resource "aws_iam_role" "athena_role" {
  name = "${var.instance_name}-${var.environment}-athena-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "athena.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name        = "${var.instance_name}-athena-role"
    Environment = var.environment
    Purpose     = "Athena service role"
    Module      = "athena"
    UseCase     = var.use_case
    Owner       = var.instance_name
  })
}

# IAM Policy for Athena
resource "aws_iam_role_policy" "athena_policy" {
  name = "${var.instance_name}-${var.environment}-athena-policy"
  role = aws_iam_role.athena_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:ListBucketMultipartUploads",
          "s3:ListMultipartUploadParts",
          "s3:AbortMultipartUpload",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          var.s3_data_bucket_arn,
          "${var.s3_data_bucket_arn}/*",
          aws_s3_bucket.athena_results.arn,
          "${aws_s3_bucket.athena_results.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "athena:*"
        ]
        Resource = [
          aws_athena_workgroup.main.arn,
          "arn:aws:athena:*:*:datacatalog/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "glue:CreateDatabase",
          "glue:DeleteDatabase",
          "glue:GetDatabase",
          "glue:GetDatabases",
          "glue:UpdateDatabase",
          "glue:CreateTable",
          "glue:DeleteTable",
          "glue:BatchDeleteTable",
          "glue:UpdateTable",
          "glue:GetTable",
          "glue:GetTables",
          "glue:BatchCreatePartition",
          "glue:CreatePartition",
          "glue:DeletePartition",
          "glue:BatchDeletePartition",
          "glue:UpdatePartition",
          "glue:GetPartition",
          "glue:GetPartitions",
          "glue:BatchGetPartition"
        ]
        Resource = "*"
      }
    ]
  })
}

# CloudWatch Log Group for Athena
resource "aws_cloudwatch_log_group" "athena_logs" {
  count             = var.enable_athena_logging ? 1 : 0
  name              = "/aws/athena/${var.instance_name}-${var.environment}"
  retention_in_days = var.athena_log_retention_days

  tags = merge(var.tags, {
    Name        = "${var.instance_name}-athena-logs"
    Environment = var.environment
    Purpose     = "Athena query logging"
    Module      = "athena"
    UseCase     = var.use_case
    Owner       = var.instance_name
  })
}

# Cost Control - CloudWatch Alarm for High Query Costs
resource "aws_cloudwatch_metric_alarm" "high_query_costs" {
  count             = var.enable_cost_alerts ? 1 : 0
  alarm_name        = "${var.instance_name}-${var.environment}-athena-high-costs"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "DataScannedInBytes"
  namespace           = "AWS/Athena"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.cost_alert_threshold_bytes
  alarm_description   = "This metric monitors Athena data scanned costs"
  alarm_actions       = var.alarm_actions

  dimensions = {
    WorkGroup = aws_athena_workgroup.main.name
  }

  tags = merge(var.tags, {
    Name        = "${var.instance_name}-athena-cost-alarm"
    Environment = var.environment
    Purpose     = "Cost monitoring for Athena queries"
    Module      = "athena"
    UseCase     = var.use_case
    Owner       = var.instance_name
  })
}