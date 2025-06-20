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
  value       = aws_lb_target_group.blue_tg.arn
}

output "green_target_group_arn" {
  description = "ARN of the green target group for blue-green deployments"
  value       = aws_lb_target_group.green_tg.arn
}

output "main_target_group_arn" {
  description = "ARN of the main target group"
  value       = aws_lb_target_group.app_tg.arn
}

output "https_listener_arn" {
  description = "ARN of the HTTPS listener for blue-green switching"
  value       = aws_lb_listener.https.arn
}
