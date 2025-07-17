# Data source to get current AWS account ID
data "aws_caller_identity" "current" {}

# IAM role for EC2 instances to access CloudWatch
resource "aws_iam_role" "ec2_cloudwatch_role" {
  name = "${var.instance_name}-${var.environment}-ec2-cloudwatch-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.instance_name}-${var.environment}-ec2-cloudwatch-role"
    Environment = var.environment
  }
}

# IAM policy for CloudWatch access
resource "aws_iam_role_policy" "ec2_cloudwatch_policy" {
  name = "${var.instance_name}-${var.environment}-ec2-cloudwatch-policy"
  role = aws_iam_role.ec2_cloudwatch_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
          "logs:DescribeLogGroups"
        ]
        Resource = "arn:aws:logs:${var.region}:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics"
        ]
        Resource = "*"
      }
    ]
  })
}

# Additional IAM policy for DynamoDB, S3, and SQS access
resource "aws_iam_role_policy" "ec2_app_policy" {
  name = "${var.instance_name}-${var.environment}-ec2-app-policy"
  role = aws_iam_role.ec2_cloudwatch_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # DynamoDB permissions for both user and feedback tables
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:BatchGetItem",
          "dynamodb:BatchWriteItem",
          "dynamodb:DescribeTable"
        ]
        Resource = [
          module.dynamodb.table_arn,
          "${module.dynamodb.table_arn}/index/*",
          module.dynamodb_feedback.table_arn,
          "${module.dynamodb_feedback.table_arn}/index/*"
        ]
      },
      # S3 permissions for all application data
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:GetObjectVersion"
        ]
        Resource = [
          "${module.s3_storage.bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = module.s3_storage.bucket_arn
      },
      # SQS permissions for feedback and analytics queues
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:GetQueueUrl",
          "sqs:GetQueueAttributes"
        ]
        Resource = concat(
          [for queue_name, queue_arn in module.sqs_processing.queue_arns : queue_arn
          if contains(["feedback", "analytics", "emails", "testflight"], queue_name)],
          [for dlq_name, dlq_arn in module.sqs_processing.dlq_arns : dlq_arn
          if contains(["feedback", "analytics", "emails", "testflight"], dlq_name)]
        )
      }
    ]
  })
}

# IAM instance profile for EC2 instances
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.instance_name}-${var.environment}-ec2-profile"
  role = aws_iam_role.ec2_cloudwatch_role.name

  tags = {
    Name        = "${var.instance_name}-${var.environment}-ec2-profile"
    Environment = var.environment
  }
}

# IAM User for Application Access
resource "aws_iam_user" "app_user" {
  name = "app_user"
  path = "/"

  tags = {
    Name        = "app_user"
    Purpose     = "Application API access for MHT"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# IAM Policy for app_user - DynamoDB access
resource "aws_iam_user_policy" "app_user_dynamodb_policy" {
  name = "app_user_dynamodb_policy"
  user = aws_iam_user.app_user.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:BatchGetItem",
          "dynamodb:BatchWriteItem",
          "dynamodb:DescribeTable"
        ]
        Resource = [
          module.dynamodb.table_arn,
          "${module.dynamodb.table_arn}/index/*",
          module.dynamodb_feedback.table_arn,
          "${module.dynamodb_feedback.table_arn}/index/*"
        ]
      }
    ]
  })
}

# IAM Policy for app_user - S3 access
resource "aws_iam_user_policy" "app_user_s3_policy" {
  name = "app_user_s3_policy"
  user = aws_iam_user.app_user.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:GetObjectVersion",
          "s3:ListBucket"
        ]
        Resource = [
          module.s3_storage.bucket_arn,
          "${module.s3_storage.bucket_arn}/*"
        ]
      }
    ]
  })
}

# IAM Policy for app_user - SQS main queues access
resource "aws_iam_user_policy" "app_user_sqs_policy" {
  name = "app_user_sqs_policy"
  user = aws_iam_user.app_user.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl",
          "sqs:ChangeMessageVisibility"
        ]
        Resource = [for queue_name, queue_arn in module.sqs_processing.queue_arns : queue_arn]
      }
    ]
  })
}

# IAM Policy for app_user - SQS DLQ access
resource "aws_iam_user_policy" "app_user_sqs_dlq_policy" {
  name = "app_user_sqs_dlq_policy"
  user = aws_iam_user.app_user.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl",
          "sqs:ChangeMessageVisibility"
        ]
        Resource = [for dlq_name, dlq_arn in module.sqs_processing.dlq_arns : dlq_arn]
      }
    ]
  })
}

# IAM Policy for app_user - CloudWatch Logs access
resource "aws_iam_user_policy" "app_user_cloudwatch_policy" {
  name = "app_user_cloudwatch_policy"
  user = aws_iam_user.app_user.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
          "logs:DescribeLogGroups"
        ]
        Resource = [
          "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:mht-logs-*",
          "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:mht-logs-*:*"
        ]
      }
    ]
  })
}