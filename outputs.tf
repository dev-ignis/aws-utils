output "instance_ids" {
  description = "The IDs of the EC2 instances"
  value       = aws_instance.my_ec2[*].id
}

output "public_ips" {
  description = "The public IPs of the EC2 instances"
  value       = aws_instance.my_ec2[*].public_ip
}

output "ssh_commands" {
  description = "SSH commands to connect to the instances. Update the key file path as needed."
  value       = [for ip in aws_instance.my_ec2[*].public_ip : "ssh -i ~/.ssh/id_rsa_github ubuntu@${ip}"]
}

output "load_balancer_dns" {
  description = "DNS name of the load balancer, if enabled"
  value       = var.enable_load_balancer ? module.alb[0].dns_name : ""
}

output "staging_api_url" {
  description = "The DNS name for the staging API endpoint"
  value       = var.staging_api_dns_name
}

output "production_api_url" {
  description = "The DNS name for the production API endpoint"
  value       = var.prod_api_dns_name
}

output "route53_records" {
  description = "Route53 records for EC2 (if any), production API, and staging API."
  value = {
    ec2_dns_record = (var.skip_route53 || var.dns_name == "" || length(aws_route53_record.ec2_dns) == 0) ? null : aws_route53_record.ec2_dns[0].name,
    api_production = (var.skip_route53 || length(aws_route53_record.api_production) == 0) ? null : aws_route53_record.api_production[0].name,
    api_staging    = (var.skip_route53 || length(aws_route53_record.api_staging) == 0) ? null : aws_route53_record.api_staging[0].name,
  }
}

# dynamodb module outputs
output "table_name" {
  description = "The name of the DynamoDB table"
  value       = module.dynamodb.table_name
}

output "table_arn" {
  description = "The ARN of the DynamoDB table"
  value       = module.dynamodb.table_arn
}
