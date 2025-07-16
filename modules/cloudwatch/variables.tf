variable "instance_name" {
  description = "Name of the instance/project"
  type        = string
}

variable "environment" {
  description = "Environment name (staging/production)"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "alb_arn_suffix" {
  description = "ALB ARN suffix for metrics"
  type        = string
}

variable "custom_namespace" {
  description = "Custom CloudWatch namespace for application metrics"
  type        = string
  default     = "AmygdalaBeta"
}

# Feature Flags
variable "enable_cloudwatch_dashboard" {
  description = "Enable CloudWatch dashboard creation"
  type        = bool
  default     = true
}

variable "enable_cloudwatch_alarms" {
  description = "Enable CloudWatch alarms"
  type        = bool
  default     = true
}

variable "enable_sns_alerts" {
  description = "Enable SNS topic for alerts"
  type        = bool
  default     = true
}

variable "enable_slack_alerts" {
  description = "Enable Slack notifications via Lambda"
  type        = bool
  default     = false
}

variable "track_engagement_metrics" {
  description = "Enable engagement metric tracking"
  type        = bool
  default     = true
}

# Alert Configuration
variable "alert_email" {
  description = "Email address for CloudWatch alerts"
  type        = string
  default     = ""
}

variable "slack_webhook_url" {
  description = "Slack webhook URL for notifications"
  type        = string
  default     = ""
  sensitive   = true
}

# Alarm Thresholds
variable "error_rate_threshold" {
  description = "Error rate percentage threshold for alarms"
  type        = number
  default     = 5  # 5% error rate
}

variable "error_rate_evaluation_periods" {
  description = "Number of periods to evaluate for error rate"
  type        = number
  default     = 2
}

variable "response_time_threshold" {
  description = "Response time threshold in seconds for p99"
  type        = number
  default     = 3  # 3 seconds
}

variable "engagement_threshold" {
  description = "Minimum engagement score threshold"
  type        = number
  default     = 50
}

variable "engagement_evaluation_periods" {
  description = "Number of periods to evaluate for engagement"
  type        = number
  default     = 4
}

# Cost Optimization
variable "dashboard_retention_days" {
  description = "Number of days to retain dashboard data"
  type        = number
  default     = 7
}

variable "enable_detailed_monitoring" {
  description = "Enable detailed monitoring (additional cost)"
  type        = bool
  default     = false
}