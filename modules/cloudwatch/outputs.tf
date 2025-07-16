output "dashboard_url" {
  description = "URL to the CloudWatch dashboard"
  value       = var.enable_cloudwatch_dashboard ? "https://console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=${aws_cloudwatch_dashboard.api_dashboard[0].dashboard_name}" : null
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for alerts"
  value       = var.enable_sns_alerts ? aws_sns_topic.cloudwatch_alerts[0].arn : null
}

output "alarm_names" {
  description = "Names of all created alarms"
  value = {
    high_error_rate    = var.enable_cloudwatch_alarms ? aws_cloudwatch_metric_alarm.high_error_rate[0].alarm_name : null
    high_response_time = var.enable_cloudwatch_alarms ? aws_cloudwatch_metric_alarm.high_response_time[0].alarm_name : null
    low_engagement     = var.enable_cloudwatch_alarms && var.track_engagement_metrics ? aws_cloudwatch_metric_alarm.low_engagement[0].alarm_name : null
  }
}

output "custom_namespace" {
  description = "Custom CloudWatch namespace for application metrics"
  value       = var.custom_namespace
}