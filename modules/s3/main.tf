# S3 Storage Module - White Label Ready
# This module creates a configurable S3 bucket with intelligent tiering and lifecycle policies
# for flexible data storage and analytics workloads

# Random ID for bucket suffix to ensure uniqueness
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# S3 Bucket for configurable data storage
resource "aws_s3_bucket" "storage" {
  bucket = "${var.instance_name}-${var.bucket_name_suffix}-${random_id.bucket_suffix.hex}"

  tags = merge(var.tags, {
    Name    = "${var.instance_name}-${var.bucket_name_suffix}"
    Purpose = "${var.use_case} with intelligent tiering"
    Module  = "s3-storage"
  })
}

# S3 Bucket versioning
resource "aws_s3_bucket_versioning" "storage_versioning" {
  bucket = aws_s3_bucket.storage.id
  versioning_configuration {
    status = var.versioning_enabled ? "Enabled" : "Disabled"
  }
}

# S3 Bucket encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "storage_encryption" {
  bucket = aws_s3_bucket.storage.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_id != null ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_id
    }
    bucket_key_enabled = true
  }
}

# S3 Bucket public access block
resource "aws_s3_bucket_public_access_block" "storage_pab" {
  bucket = aws_s3_bucket.storage.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Intelligent Tiering Configuration - Primary Data
resource "aws_s3_bucket_intelligent_tiering_configuration" "primary_data_tiering" {
  count  = var.enable_intelligent_tiering ? 1 : 0
  bucket = aws_s3_bucket.storage.id
  name   = "${var.use_case}-primary-tiering"
  status = "Enabled"

  # Filter to apply intelligent tiering to primary data partition
  filter {
    prefix = var.primary_data_prefix
  }

  # Archive configurations for cost optimization
  dynamic "tiering" {
    for_each = var.tiering_configurations
    content {
      access_tier = tiering.value.access_tier
      days        = tiering.value.days
    }
  }
}

# S3 Intelligent Tiering Configuration - Secondary Data Prefixes
resource "aws_s3_bucket_intelligent_tiering_configuration" "secondary_data_tiering" {
  count  = var.enable_intelligent_tiering && length(var.secondary_data_prefixes) > 0 ? length(var.secondary_data_prefixes) : 0
  bucket = aws_s3_bucket.storage.id
  name   = "${var.use_case}-secondary-tiering-${count.index}"
  status = "Enabled"

  # Filter to apply intelligent tiering to secondary data partitions
  filter {
    prefix = var.secondary_data_prefixes[count.index]
  }

  # Archive configurations for cost optimization
  dynamic "tiering" {
    for_each = var.tiering_configurations
    content {
      access_tier = tiering.value.access_tier
      days        = tiering.value.days
    }
  }
}

# S3 Lifecycle Configuration for comprehensive cost optimization
resource "aws_s3_bucket_lifecycle_configuration" "storage_lifecycle" {
  count  = var.enable_lifecycle_policy ? 1 : 0
  bucket = aws_s3_bucket.storage.id

  rule {
    id     = "${var.use_case}-main-lifecycle-rule"
    status = "Enabled"

    filter {
      prefix = ""
    }

    # Standard-IA transition
    dynamic "transition" {
      for_each = var.lifecycle_transitions
      content {
        days          = transition.value.days
        storage_class = transition.value.storage_class
      }
    }

    # Non-current version transitions
    noncurrent_version_transition {
      noncurrent_days = var.noncurrent_version_transition_days
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_expiration_days
    }

    # Clean up incomplete multipart uploads
    abort_incomplete_multipart_upload {
      days_after_initiation = var.multipart_upload_cleanup_days
    }
  }

  # Dynamic rules for temporary data prefixes
  dynamic "rule" {
    for_each = var.temp_prefixes
    content {
      id     = "${var.use_case}-${rule.key}-cleanup"
      status = "Enabled"

      filter {
        prefix = "${rule.value.prefix}/"
      }

      expiration {
        days = rule.value.expiration_days
      }
    }
  }
}

# IAM Role for S3 storage access
resource "aws_iam_role" "s3_storage_access_role" {
  name = "${var.instance_name}-s3-${var.use_case}-access-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = var.trusted_services
        }
      }
    ], length(var.trusted_accounts) > 0 ? [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        AWS = [for account in var.trusted_accounts : "arn:aws:iam::${account}:root"]
      }
      Condition = {
        StringEquals = {
          "sts:ExternalId" = "${var.instance_name}-${var.use_case}"
        }
      }
    }] : [])
  })

  tags = merge(var.tags, {
    Name    = "${var.instance_name}-s3-${var.use_case}-access-role"
    Purpose = "S3 ${var.use_case} access permissions"
    Module  = "s3-storage"
  })
}

# IAM Policy for S3 storage access
resource "aws_iam_role_policy" "s3_storage_access_policy" {
  name = "${var.instance_name}-s3-${var.use_case}-access-policy"
  role = aws_iam_role.s3_storage_access_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = var.s3_permissions
        Resource = [
          aws_s3_bucket.storage.arn,
          "${aws_s3_bucket.storage.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetBucketLocation",
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.storage.arn
      }
    ]
  })
}

# Instance profile for EC2 instances
resource "aws_iam_instance_profile" "s3_storage_access_profile" {
  name = "${var.instance_name}-s3-${var.use_case}-access-profile"
  role = aws_iam_role.s3_storage_access_role.name
}

# Optional Read-Only IAM Role
resource "aws_iam_role" "s3_readonly_role" {
  count = var.create_read_only_role ? 1 : 0
  name  = "${var.instance_name}-s3-${var.use_case}-readonly-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = var.trusted_services
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name    = "${var.instance_name}-s3-${var.use_case}-readonly-role"
    Purpose = "S3 ${var.use_case} read-only access"
    Module  = "s3-storage"
  })
}

resource "aws_iam_role_policy" "s3_readonly_policy" {
  count = var.create_read_only_role ? 1 : 0
  name  = "${var.instance_name}-s3-${var.use_case}-readonly-policy"
  role  = aws_iam_role.s3_readonly_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          aws_s3_bucket.storage.arn,
          "${aws_s3_bucket.storage.arn}/*"
        ]
      }
    ]
  })
}

# Optional Admin IAM Role
resource "aws_iam_role" "s3_admin_role" {
  count = var.create_admin_role ? 1 : 0
  name  = "${var.instance_name}-s3-${var.use_case}-admin-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = var.trusted_services
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name    = "${var.instance_name}-s3-${var.use_case}-admin-role"
    Purpose = "S3 ${var.use_case} administrative access"
    Module  = "s3-storage"
  })
}

resource "aws_iam_role_policy" "s3_admin_policy" {
  count = var.create_admin_role ? 1 : 0
  name  = "${var.instance_name}-s3-${var.use_case}-admin-policy"
  role  = aws_iam_role.s3_admin_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "s3:*"
        Resource = [
          aws_s3_bucket.storage.arn,
          "${aws_s3_bucket.storage.arn}/*"
        ]
      }
    ]
  })
}

# S3 Bucket notification configuration
resource "aws_s3_bucket_notification" "storage_notification" {
  count  = length(var.notification_configurations) > 0 ? 1 : 0
  bucket = aws_s3_bucket.storage.id

  dynamic "lambda_function" {
    for_each = var.notification_configurations
    content {
      lambda_function_arn = lambda_function.value.lambda_function_arn
      events              = lambda_function.value.events
      filter_prefix       = lambda_function.value.filter_prefix
      filter_suffix       = lambda_function.value.filter_suffix
    }
  }
}

# S3 Bucket policy for secure access
resource "aws_s3_bucket_policy" "storage_bucket_policy" {
  bucket = aws_s3_bucket.storage.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Sid       = "DenyInsecureConnections"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.storage.arn,
          "${aws_s3_bucket.storage.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
      {
        Sid    = "AllowStorageAccessRole"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.s3_storage_access_role.arn
        }
        Action = var.s3_permissions
        Resource = [
          aws_s3_bucket.storage.arn,
          "${aws_s3_bucket.storage.arn}/*"
        ]
      }
    ], var.additional_bucket_policy_statements)
  })
}

# CloudWatch Log Group for S3 access logging
resource "aws_cloudwatch_log_group" "s3_access_logs" {
  count             = var.enable_access_logging ? 1 : 0
  name              = "/aws/s3/${aws_s3_bucket.storage.id}/access-logs"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name    = "${var.instance_name}-s3-${var.use_case}-access-logs"
    Purpose = "S3 ${var.use_case} access logging"
    Module  = "s3-storage"
  })
}

# Athena partitioning setup - Create example partition structure
resource "aws_s3_object" "partition_structure_examples" {
  for_each = var.create_partition_examples ? toset([
    "${var.primary_data_prefix}year=${formatdate("YYYY", timestamp())}/month=${formatdate("MM", timestamp())}/day=${formatdate("DD", timestamp())}/hour=00/.keep",
    "${var.primary_data_prefix}year=${formatdate("YYYY", timestamp())}/month=${formatdate("MM", timestamp())}/day=${formatdate("DD", timestamp())}/hour=01/.keep",
    "processed/year=${formatdate("YYYY", timestamp())}/month=${formatdate("MM", timestamp())}/day=${formatdate("DD", timestamp())}/hour=00/.keep",
    "${keys(var.temp_prefixes)[0]}/.keep"
  ]) : []

  bucket  = aws_s3_bucket.storage.id
  key     = each.value
  content = "# ${var.use_case} partition structure example"

  tags = merge(var.tags, {
    Module = "s3-storage"
  })
}