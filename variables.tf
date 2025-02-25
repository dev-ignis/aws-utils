variable "region" {
  type    = string
  default = "us-west-2"
}

variable "ami" {
  description = "The AMI to use for the EC2 instance"
  type        = string
}

variable "instance_type" {
  description = "The EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "instance_name" {
  description = "Name tag for the EC2 instance"
  type        = string
}

variable "key_name" {
  description = "The key pair to use for SSH access"
  type        = string
}

variable "dns_name" {
  description = "The DNS record name to assign to the instance"
  type        = string
  default     = ""
}

variable "docker_image" {
  description = "The Docker image (including tag) to deploy on the instance"
  type        = string
}

variable "certbot_email" {
  description = "Email to use for Certbot to obtain SSL certificates"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the custom VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidrs" {
  description = "List of CIDR blocks for the subnets (at least two)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "availability_zones" {
  description = "List of availability zones for the subnets (at least two)"
  type        = list(string)
  default     = ["us-west-2a", "us-west-2b"]
}

variable "app_port" {
  description = "The port on which the application runs"
  type        = string
  default     = "5000"
}

variable "app_container_name" {
  description = "Name for the Docker container running the application"
  type        = string
  default     = "site_spidey_app"
}

variable "enable_load_balancer" {
  description = "Enable or disable the load balancer"
  type        = bool
  default     = false
}

variable "route53_zone_id" {
  description = "The Route53 hosted zone ID for creating DNS records"
  type        = string
}

variable "go_gin_app_image" {
  description = "Docker image for the Go Gin application"
  type        = string
}
