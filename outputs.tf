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
  description = "Route53 records for EC2 (if any), production API, staging API, and certificate validation."
  value = {
    ec2_dns_record = try(aws_route53_record.ec2_dns[0].name, null)
    api_production = try(aws_route53_record.api_production[0].name, null)
    api_staging    = try(aws_route53_record.api_staging[0].name, null)
    www            = try(aws_route53_record.www[0].name, null)
    apex           = try(aws_route53_record.apex[0].name, null)
    cert_validation = try({
      for k, v in module.alb[0].aws_route53_record.cert_validation : k => v.name
    }, {})
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

# ALB and Blue-Green Deployment Outputs
output "alb_https_listener_arn" {
  description = "ARN of the ALB HTTPS listener for blue-green deployments"
  value       = var.enable_load_balancer ? module.alb[0].https_listener_arn : ""
}

output "blue_target_group_arn" {
  description = "ARN of the blue target group"
  value       = var.enable_load_balancer ? module.alb[0].blue_target_group_arn : ""
}

output "green_target_group_arn" {
  description = "ARN of the green target group"
  value       = var.enable_load_balancer ? module.alb[0].green_target_group_arn : ""
}

output "main_target_group_arn" {
  description = "ARN of the main target group (for rolling deployments)"
  value       = var.enable_load_balancer ? module.alb[0].main_target_group_arn : ""
}

# Configuration and Environment Outputs
output "environment" {
  description = "The deployment environment"
  value       = var.environment
}

output "region" {
  description = "The AWS region"
  value       = var.region
}

output "domain_name" {
  description = "The primary domain name"
  value       = var.hosted_zone_name
}

output "discord_configuration" {
  description = "Discord notification configuration"
  value = {
    enabled     = var.enable_discord_notifications
    webhook_url = var.discord_webhook_url != "" ? "configured" : "not_configured"
  }
  sensitive = true
}

# S3 Storage Outputs - White Label Ready
output "s3_bucket_id" {
  description = "ID of the S3 storage bucket"
  value       = module.s3_storage.bucket_id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 storage bucket"
  value       = module.s3_storage.bucket_arn
}

output "s3_bucket_name" {
  description = "Name of the S3 storage bucket"
  value       = module.s3_storage.bucket_name
}

output "s3_storage_access_role_arn" {
  description = "ARN of the IAM role for S3 storage access"
  value       = module.s3_storage.storage_access_role_arn
}

output "s3_instance_profile_name" {
  description = "Name of the IAM instance profile for S3 access"
  value       = module.s3_storage.instance_profile_name
}

output "s3_readonly_role_arn" {
  description = "ARN of the read-only IAM role (if created)"
  value       = module.s3_storage.readonly_role_arn
}

output "s3_admin_role_arn" {
  description = "ARN of the admin IAM role (if created)"
  value       = module.s3_storage.admin_role_arn
}

output "s3_athena_partition_info" {
  description = "Information on how to structure data for Athena partitioning"
  value       = module.s3_storage.athena_partition_info
}

output "s3_integration_guide" {
  description = "Integration patterns for the S3 storage bucket"
  value       = module.s3_storage.integration_guide
}

output "s3_cost_optimization_features" {
  description = "Summary of S3 cost optimization features enabled"
  value       = module.s3_storage.cost_optimization_features
}

output "s3_white_label_configuration" {
  description = "White label configuration summary"
  value       = module.s3_storage.white_label_configuration
}

# SQS Processing Outputs - White Label Ready
output "sqs_queue_urls" {
  description = "URLs of all SQS queues"
  value       = module.sqs_processing.queue_urls
}

output "sqs_queue_arns" {
  description = "ARNs of all SQS queues"
  value       = module.sqs_processing.queue_arns
}

output "sqs_queue_names" {
  description = "Names of all SQS queues"
  value       = module.sqs_processing.queue_names
}

output "sqs_dlq_urls" {
  description = "URLs of all SQS dead letter queues"
  value       = module.sqs_processing.dlq_urls
}

output "sqs_api_service_role_arn" {
  description = "ARN of the SQS API service IAM role"
  value       = module.sqs_processing.api_service_role_arn
}

output "sqs_worker_service_role_arn" {
  description = "ARN of the SQS worker service IAM role"
  value       = module.sqs_processing.worker_service_role_arn
}

output "sqs_api_service_instance_profile_name" {
  description = "Name of the SQS API service instance profile"
  value       = module.sqs_processing.api_service_instance_profile_name
}

output "sqs_worker_service_instance_profile_name" {
  description = "Name of the SQS worker service instance profile"
  value       = module.sqs_processing.worker_service_instance_profile_name
}

output "sqs_integration_guide" {
  description = "SQS integration patterns and usage examples"
  value       = module.sqs_processing.integration_guide
}

output "sqs_configuration_summary" {
  description = "Summary of SQS queue configurations and settings"
  value       = module.sqs_processing.queue_configuration_summary
}

output "sqs_white_label_configuration" {
  description = "SQS white label configuration summary"
  value       = module.sqs_processing.white_label_configuration
}

output "sqs_cost_optimization_features" {
  description = "Summary of SQS cost optimization features enabled"
  value       = module.sqs_processing.cost_optimization_features
}

output "sqs_cloudwatch_dashboard_config" {
  description = "CloudWatch dashboard configuration for SQS monitoring"
  value       = module.sqs_processing.cloudwatch_dashboard_config
}
