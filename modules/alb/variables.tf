variable "instance_name" {
  description = "The instance name used in naming resources"
  type        = string
}

variable "app_port" {
  description = "Port on which the app listens"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for the target group"
  type        = string
}

variable "lb_subnet_ids" {
  description = "Subnets for the ALB"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security Group ID for the ALB"
  type        = string
}

variable "instance_ids" {
  description = "List of instance IDs for the target group attachment"
  type        = list(string)
}

variable "staging_api_dns_name" {
  description = "DNS name for the staging API endpoint used in the ALB listener rule"
  type        = string
}
