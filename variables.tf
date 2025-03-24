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
  default     = "8080"
}

variable "app_container_name" {
  description = "Name for the Docker container running the application"
  type        = string
  default     = "mht-api-app"
}

variable "enable_load_balancer" {
  description = "Enable or disable the load balancer"
  type        = bool
  default     = false
}

variable "go_gin_app_image" {
  description = "Docker image for the Go Gin application"
  type        = string
}

variable "ssh_private_key_path" {
  description = "Path to the SSH private key used for connecting to EC2 instances"
  type        = string
  default     = "~/.ssh/id_rsa_github"
}

variable "route53_zone_id" {
  description = "The ID of the Route53 hosted zone"
  type        = string
}

variable "staging_api_dns_name" {
  description = "DNS name for the staging API endpoint"
  type        = string
  default     = ""
}

variable "prod_api_dns_name" {
  description = "DNS name for the staging API endpoint"
  type        = string
  default     = ""
}

variable "create_hosted_zone" {
  description = "Whether to create a new Route53 hosted zone if not already available"
  type        = bool
  default     = false
}

variable "hosted_zone_name" {
  description = "The name of the hosted zone to create (e.g., amygdalas.com)"
  type        = string
  default     = ""
}

# Remote Backend
#variable "backend_bucket" {
#  description = "The S3 bucket for storing Terraform state"
#  type        = string
#}
#
#variable "backend_key" {
#  description = "The path inside the S3 bucket for the state file"
#  type        = string
#  default     = "terraform/state/terraform.tfstate"
#}
#
#variable "backend_region" {
#  description = "The AWS region where the S3 bucket is located"
#  type        = string
#  default     = "us-west-2"
#}
#
#variable "backend_encrypt" {
#  description = "Whether to encrypt the state file"
#  type        = bool
#  default     = true
#}
#
#variable "backend_dynamodb_table" {
#  description = "The DynamoDB table for state locking"
#  type        = string
#}

variable "skip_route53" {
  description = "Skip creating Route53 DNS records if true (e.g., in CI)"
  type        = bool
  default     = false
}

variable "environment" {
  description = "The environment in which resources are deployed (e.g., dev, staging, prod)"
  type        = string
}

variable "backend_image" {
  description = "Docker image for the backend app (e.g. Go Gin app)"
  type        = string
  default     = "rollg/go-gin-app"
}

variable "front_end_image" {
  description = "Docker image for the front-end app"
  type        = string
}

variable "backend_container_name" {
  description = "Container name for the backend app"
  type        = string
  default     = "backend_app"
}

variable "front_end_container_name" {
  description = "Container name for the front-end app"
  type        = string
  default     = "front_end_app"
}

variable "backend_port" {
  description = "Port on which the backend app listens"
  type        = string
  default     = "5000"
}

variable "front_end_port" {
  description = "Port on which the front-end app listens"
  type        = string
  default     = "3000"
}
