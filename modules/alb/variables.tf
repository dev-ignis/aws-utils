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
  description = "DNS name for staging API"
  type        = string
}

variable "domain_name" {
  description = "Domain name for the ALB"
  type        = string
}

variable "environment" {
  description = "Environment name for resource tagging"
  type        = string
}

variable "route53_zone_id" {
  description = "Route53 zone ID"
  type        = string
}

variable "skip_route53" {
  description = "Whether to skip Route53 record creation"
  type        = bool
  default     = false
}

variable "blue_green_enabled" {
  description = "Enable blue-green deployment target groups"
  type        = bool
  default     = false
}

variable "active_target_group" {
  description = "Active target group for blue-green deployment (blue or green)"
  type        = string
  default     = "blue"
  validation {
    condition     = contains(["blue", "green"], var.active_target_group)
    error_message = "active_target_group must be either 'blue' or 'green'"
  }
}
