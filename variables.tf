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

variable "route53_zone_id" {
  description = "The Route53 hosted zone id"
  type        = string
}

variable "dns_name" {
  description = "The DNS record name to assign to the instance"
  type        = string
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

variable "subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "availability_zone" {
  description = "Availability Zone for the subnet"
  type        = string
  default     = "us-west-2a"
}

variable "app_port" {
  description = "The port on which the application runs"
  type        = string
  default     = "5000"
}
