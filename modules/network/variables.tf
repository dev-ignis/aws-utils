variable "instance_name" {
  description = "Name tag for resources"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "subnet_cidrs" {
  description = "List of CIDR blocks for the subnets (at least two)"
  type        = list(string)
}

variable "availability_zones" {
  description = "List of availability zones for the subnets (at least two)"
  type        = list(string)
}

variable "app_port" {
  description = "The port on which the application runs"
  type        = string
}
