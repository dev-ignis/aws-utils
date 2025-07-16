# CloudWatch Dashboard for API Performance Monitoring
resource "aws_cloudwatch_dashboard" "api_dashboard" {
  count          = var.enable_cloudwatch_dashboard ? 1 : 0
  dashboard_name = "${var.instance_name}-${var.environment}-api-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      # API Request Count
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.alb_arn_suffix, { stat = "Sum" }]
          ]
          period = 300
          stat   = "Sum"
          region = var.region
          title  = "API Request Count"
        }
      },
      # API Latency
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.alb_arn_suffix, { stat = "Average" }],
            [".", ".", ".", ".", { stat = "p99", label = "p99" }]
          ]
          period = 300
          stat   = "Average"
          region = var.region
          title  = "API Response Time"
        }
      },
      # Error Rates
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_Target_4XX_Count", "LoadBalancer", var.alb_arn_suffix, { stat = "Sum" }],
            [".", "HTTPCode_Target_5XX_Count", ".", ".", { stat = "Sum" }]
          ]
          period = 300
          stat   = "Sum"
          region = var.region
          title  = "API Error Rates"
        }
      },
      # Custom Metrics
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["${var.custom_namespace}", "UserEngagement", { stat = "Average" }],
            [".", "ActiveSessions", { stat = "Sum" }]
          ]
          period = 300
          stat   = "Average"
          region = var.region
          title  = "User Engagement Metrics"
        }
      }
    ]
  })
}

# SNS Topic for Alerts
resource "aws_sns_topic" "cloudwatch_alerts" {
  count = var.enable_sns_alerts ? 1 : 0
  name  = "${var.instance_name}-${var.environment}-cloudwatch-alerts"

  tags = {
    Environment = var.environment
    Purpose     = "CloudWatch Alarm Notifications"
  }
}

# Email Subscription
resource "aws_sns_topic_subscription" "email_alerts" {
  count     = var.enable_sns_alerts && var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.cloudwatch_alerts[0].arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# Slack Webhook (using Lambda)
# TODO: Implement Lambda function for Slack notifications
# resource "aws_sns_topic_subscription" "slack_alerts" {
#   count     = var.enable_sns_alerts && var.enable_slack_alerts ? 1 : 0
#   topic_arn = aws_sns_topic.cloudwatch_alerts[0].arn
#   protocol  = "lambda"
#   endpoint  = aws_lambda_function.slack_notifier[0].arn
# }

# High Error Rate Alarm
resource "aws_cloudwatch_metric_alarm" "high_error_rate" {
  count               = var.enable_cloudwatch_alarms ? 1 : 0
  alarm_name          = "${var.instance_name}-${var.environment}-high-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.error_rate_evaluation_periods
  threshold           = var.error_rate_threshold
  alarm_description   = "This metric monitors API error rate"
  alarm_actions       = var.enable_sns_alerts ? [aws_sns_topic.cloudwatch_alerts[0].arn] : []

  metric_query {
    id          = "error_rate"
    expression  = "(m1+m2)/m3*100"
    label       = "Error Rate %"
    return_data = true
  }

  metric_query {
    id = "m1"
    metric {
      metric_name = "HTTPCode_Target_4XX_Count"
      namespace   = "AWS/ApplicationELB"
      period      = 300
      stat        = "Sum"
      dimensions = {
        LoadBalancer = var.alb_arn_suffix
      }
    }
  }

  metric_query {
    id = "m2"
    metric {
      metric_name = "HTTPCode_Target_5XX_Count"
      namespace   = "AWS/ApplicationELB"
      period      = 300
      stat        = "Sum"
      dimensions = {
        LoadBalancer = var.alb_arn_suffix
      }
    }
  }

  metric_query {
    id = "m3"
    metric {
      metric_name = "RequestCount"
      namespace   = "AWS/ApplicationELB"
      period      = 300
      stat        = "Sum"
      dimensions = {
        LoadBalancer = var.alb_arn_suffix
      }
    }
  }
}

# Low Engagement Alarm
resource "aws_cloudwatch_metric_alarm" "low_engagement" {
  count               = var.enable_cloudwatch_alarms && var.track_engagement_metrics ? 1 : 0
  alarm_name          = "${var.instance_name}-${var.environment}-low-engagement"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = var.engagement_evaluation_periods
  metric_name         = "UserEngagement"
  namespace           = var.custom_namespace
  period              = 900
  statistic           = "Average"
  threshold           = var.engagement_threshold
  alarm_description   = "This metric monitors user engagement"
  alarm_actions       = var.enable_sns_alerts ? [aws_sns_topic.cloudwatch_alerts[0].arn] : []
  treat_missing_data  = "notBreaching"
}

# High Response Time Alarm
resource "aws_cloudwatch_metric_alarm" "high_response_time" {
  count               = var.enable_cloudwatch_alarms ? 1 : 0
  alarm_name          = "${var.instance_name}-${var.environment}-high-response-time"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  extended_statistic  = "p99"
  threshold           = var.response_time_threshold
  alarm_description   = "This metric monitors API response time (99th percentile)"
  alarm_actions       = var.enable_sns_alerts ? [aws_sns_topic.cloudwatch_alerts[0].arn] : []
  
  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }
}