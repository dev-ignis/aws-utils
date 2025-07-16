output "dns_name" {
  description = "DNS name of the load balancer"
  value       = aws_lb.app_lb.dns_name
}

output "lb_dns_name" {
  description = "The DNS name of the load balancer"
  value       = aws_lb.app_lb.dns_name
}

output "lb_zone_id" {
  description = "The hosted zone ID associated with the load balancer"
  value       = aws_lb.app_lb.zone_id
}

output "blue_target_group_arn" {
  description = "ARN of the blue target group for blue-green deployments"
  value       = var.blue_green_enabled ? aws_lb_target_group.blue_tg[0].arn : null
}

output "green_target_group_arn" {
  description = "ARN of the green target group for blue-green deployments"
  value       = var.blue_green_enabled ? aws_lb_target_group.green_tg[0].arn : null
}

output "main_target_group_arn" {
  description = "ARN of the main target group"
  value       = aws_lb_target_group.app_tg.arn
}

output "https_listener_arn" {
  description = "ARN of the HTTPS listener for blue-green switching"
  value       = aws_lb_listener.https.arn
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.app_lb.arn
}

output "alb_arn_suffix" {
  description = "ARN suffix of the Application Load Balancer for CloudWatch metrics"
  value       = aws_lb.app_lb.arn_suffix
}
