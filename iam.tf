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

# IAM instance profile for EC2 instances
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.instance_name}-${var.environment}-ec2-profile"
  role = aws_iam_role.ec2_cloudwatch_role.name

  tags = {
    Name        = "${var.instance_name}-${var.environment}-ec2-profile"
    Environment = var.environment
  }
}