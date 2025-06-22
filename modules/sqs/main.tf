# White Label SQS Module for Asynchronous Processing
# Supports FIFO and Standard queues with configurable naming and features

# Generate random suffix for unique naming
resource "random_id" "queue_suffix" {
  byte_length = 4
}

locals {
  # Queue naming pattern: {instance_name}-{use_case}-{queue_name}-{suffix}
  queue_name_prefix = "${var.instance_name}-${var.use_case}"
  
  # Common queue configuration
  common_tags = merge(var.tags, {
    Module    = "sqs"
    UseCase   = var.use_case
    Owner     = var.instance_name
    CreatedBy = "terraform"
  })
}

# Main Queues Configuration
resource "aws_sqs_queue" "main_queues" {
  for_each = var.queue_configurations
  
  name                      = each.value.fifo_queue ? "${local.queue_name_prefix}-${each.key}.fifo" : "${local.queue_name_prefix}-${each.key}"
  fifo_queue               = each.value.fifo_queue
  content_based_deduplication = each.value.fifo_queue ? each.value.content_based_deduplication : null
  
  # Message configuration
  message_retention_seconds = each.value.message_retention_seconds
  visibility_timeout_seconds = each.value.visibility_timeout_seconds
  max_message_size          = each.value.max_message_size
  delay_seconds            = each.value.delay_seconds
  receive_wait_time_seconds = each.value.receive_wait_time_seconds
  
  # Dead letter queue configuration
  redrive_policy = each.value.enable_dlq ? jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dead_letter_queues[each.key].arn
    maxReceiveCount     = each.value.max_receive_count
  }) : null
  
  # Encryption
  kms_master_key_id                 = var.enable_encryption ? (var.kms_key_id != null ? var.kms_key_id : "alias/aws/sqs") : null
  kms_data_key_reuse_period_seconds = var.enable_encryption ? 300 : null
  
  tags = merge(local.common_tags, {
    Name      = "${local.queue_name_prefix}-${each.key}"
    QueueType = each.value.fifo_queue ? "FIFO" : "Standard"
    Purpose   = each.value.description
  })
}

# Dead Letter Queues
resource "aws_sqs_queue" "dead_letter_queues" {
  for_each = { for k, v in var.queue_configurations : k => v if v.enable_dlq }
  
  name                      = each.value.fifo_queue ? "${local.queue_name_prefix}-${each.key}-dlq.fifo" : "${local.queue_name_prefix}-${each.key}-dlq"
  fifo_queue               = each.value.fifo_queue
  content_based_deduplication = each.value.fifo_queue ? true : null
  
  # Extended retention for DLQ analysis
  message_retention_seconds = var.dlq_message_retention_seconds
  visibility_timeout_seconds = each.value.visibility_timeout_seconds
  
  # Encryption (same as main queue)
  kms_master_key_id                 = var.enable_encryption ? (var.kms_key_id != null ? var.kms_key_id : "alias/aws/sqs") : null
  kms_data_key_reuse_period_seconds = var.enable_encryption ? 300 : null
  
  tags = merge(local.common_tags, {
    Name      = "${local.queue_name_prefix}-${each.key}-dlq"
    QueueType = each.value.fifo_queue ? "FIFO-DLQ" : "Standard-DLQ"
    Purpose   = "Dead Letter Queue for ${each.key}"
  })
}

# IAM Role for API Services (Send Messages)
resource "aws_iam_role" "api_service_role" {
  count = var.create_api_service_role ? 1 : 0
  
  name = "${local.queue_name_prefix}-api-service-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = [
            "ec2.amazonaws.com",
            "ecs-tasks.amazonaws.com",
            "lambda.amazonaws.com"
          ]
        }
      }
    ]
  })
  
  tags = merge(local.common_tags, {
    Name = "${local.queue_name_prefix}-api-service-role"
    Role = "API-Service"
  })
}

# IAM Policy for API Services
resource "aws_iam_role_policy" "api_service_policy" {
  count = var.create_api_service_role ? 1 : 0
  
  name = "${local.queue_name_prefix}-api-service-policy"
  role = aws_iam_role.api_service_role[0].id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl"
        ]
        Resource = [
          for queue in aws_sqs_queue.main_queues : queue.arn
        ]
      },
      # KMS permissions for encrypted queues
      var.enable_encryption ? {
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = var.kms_key_id != null ? [var.kms_key_id] : ["arn:aws:kms:*:*:alias/aws/sqs"]
      } : null
    ]
  })
}

# IAM Role for Worker Services (Receive/Delete Messages)
resource "aws_iam_role" "worker_service_role" {
  count = var.create_worker_service_role ? 1 : 0
  
  name = "${local.queue_name_prefix}-worker-service-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = [
            "ec2.amazonaws.com",
            "ecs-tasks.amazonaws.com",
            "lambda.amazonaws.com"
          ]
        }
      }
    ]
  })
  
  tags = merge(local.common_tags, {
    Name = "${local.queue_name_prefix}-worker-service-role"
    Role = "Worker-Service"
  })
}

# IAM Policy for Worker Services
resource "aws_iam_role_policy" "worker_service_policy" {
  count = var.create_worker_service_role ? 1 : 0
  
  name = "${local.queue_name_prefix}-worker-service-policy"
  role = aws_iam_role.worker_service_role[0].id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:ChangeMessageVisibility",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl"
        ]
        Resource = concat(
          [for queue in aws_sqs_queue.main_queues : queue.arn],
          [for queue in aws_sqs_queue.dead_letter_queues : queue.arn]
        )
      }], 
      var.enable_encryption ? [{
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = var.kms_key_id != null ? [var.kms_key_id] : ["arn:aws:kms:*:*:alias/aws/sqs"]
      }] : [],
      var.enable_s3_integration && var.s3_bucket_arn != "" ? [{
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:GetObject",
          "s3:GetObjectAcl",
          "s3:DeleteObject"
        ]
        Resource = "${var.s3_bucket_arn}/*"
      }, {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = var.s3_bucket_arn
      }] : []
    )
  })
}

# Instance Profiles for EC2 if needed
resource "aws_iam_instance_profile" "api_service_profile" {
  count = var.create_api_service_role && var.create_instance_profiles ? 1 : 0
  
  name = "${local.queue_name_prefix}-api-service-profile"
  role = aws_iam_role.api_service_role[0].name
  
  tags = merge(local.common_tags, {
    Name = "${local.queue_name_prefix}-api-service-profile"
  })
}

resource "aws_iam_instance_profile" "worker_service_profile" {
  count = var.create_worker_service_role && var.create_instance_profiles ? 1 : 0
  
  name = "${local.queue_name_prefix}-worker-service-profile"
  role = aws_iam_role.worker_service_role[0].name
  
  tags = merge(local.common_tags, {
    Name = "${local.queue_name_prefix}-worker-service-profile"
  })
}

# CloudWatch Alarms for Queue Monitoring
resource "aws_cloudwatch_metric_alarm" "queue_depth_alarm" {
  for_each = var.enable_cloudwatch_alarms ? var.queue_configurations : {}
  
  alarm_name          = "${local.queue_name_prefix}-${each.key}-depth-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ApproximateNumberOfVisibleMessages"
  namespace           = "AWS/SQS"
  period              = "300"
  statistic           = "Average"
  threshold           = each.value.alarm_max_depth
  alarm_description   = "This metric monitors ${each.key} queue depth"
  alarm_actions       = var.cloudwatch_alarm_actions
  
  dimensions = {
    QueueName = aws_sqs_queue.main_queues[each.key].name
  }
  
  tags = merge(local.common_tags, {
    Name = "${local.queue_name_prefix}-${each.key}-depth-alarm"
  })
}

# CloudWatch Alarms for Dead Letter Queues
resource "aws_cloudwatch_metric_alarm" "dlq_alarm" {
  for_each = var.enable_cloudwatch_alarms ? { for k, v in var.queue_configurations : k => v if v.enable_dlq } : {}
  
  alarm_name          = "${local.queue_name_prefix}-${each.key}-dlq-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "ApproximateNumberOfVisibleMessages"
  namespace           = "AWS/SQS"
  period              = "300"
  statistic           = "Average"
  threshold           = "0"
  alarm_description   = "This metric monitors ${each.key} dead letter queue for failed messages"
  alarm_actions       = var.cloudwatch_alarm_actions
  
  dimensions = {
    QueueName = aws_sqs_queue.dead_letter_queues[each.key].name
  }
  
  tags = merge(local.common_tags, {
    Name = "${local.queue_name_prefix}-${each.key}-dlq-alarm"
  })
}

# CloudWatch Log Group for SQS Operations (if enabled)
resource "aws_cloudwatch_log_group" "sqs_operations" {
  count = var.enable_operations_logging ? 1 : 0
  
  name              = "/aws/sqs/${local.queue_name_prefix}"
  retention_in_days = var.log_retention_days
  
  tags = merge(local.common_tags, {
    Name = "${local.queue_name_prefix}-operations-logs"
  })
}