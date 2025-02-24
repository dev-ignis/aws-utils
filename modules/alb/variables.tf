variable "instance_name" {
  description = "Name tag for resources"
  type        = string
}

variable "app_port" {
  description = "The port on which the application runs"
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC"
  type        = string
}

variable "lb_subnet_ids" {
  description = "List of subnet IDs for the load balancer"
  type        = list(string)
}

variable "security_group_id" {
  description = "The ID of the security group for the load balancer"
  type        = string
}

variable "instance_id" {
  description = "The EC2 instance ID to attach to the target group"
  type        = string
}
