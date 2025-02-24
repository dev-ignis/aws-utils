output "dns_name" {
  description = "DNS name of the load balancer"
  value       = aws_lb.app_lb.dns_name
}
