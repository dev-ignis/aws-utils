##############################
# General AWS & Infrastructure
##############################
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

variable "enable_load_balancer" {
  description = "Enable or disable the load balancer"
  type        = bool
  default     = false
}

variable "skip_route53" {
  description = "Skip creating Route53 DNS records if true (e.g., in CI)"
  type        = bool
  default     = false
}

variable "environment" {
  description = "The environment in which resources are deployed (e.g., dev, staging, prod)"
  type        = string
}

##############################
# Route53 & Hosted Zone
##############################
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
  description = "DNS name for the production API endpoint"
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

variable "create_apex_record" {
  description = "Whether to create an A record for the apex/root domain"
  type        = bool
  default     = true
}

variable "create_mail_records" {
  description = "Whether to create email-related DNS records (MX, SPF, DKIM, DMARC)"
  type        = bool
  default     = false
}

variable "mx_records" {
  description = "List of MX records for the domain (e.g., ['10 mail.example.com', '20 mail2.example.com'])"
  type        = list(string)
  default     = []
}

variable "spf_record" {
  description = "SPF record value (e.g., 'include:_spf.google.com include:amazonses.com ~all')"
  type        = string
  default     = "include:_spf.google.com"
}

variable "dkim_records" {
  description = "List of DKIM TXT record values"
  type        = list(string)
  default     = []
}

variable "dkim_selector" {
  description = "DKIM selector name (e.g., 'google' for Google Workspace)"
  type        = string
  default     = "default"
}

variable "dmarc_policy" {
  description = "DMARC policy (none, quarantine, or reject)"
  type        = string
  default     = "none"
}

variable "dmarc_email" {
  description = "Email address to receive DMARC reports"
  type        = string
  default     = "admin@example.com"
}

variable "create_wildcard_record" {
  description = "Whether to create a wildcard record for the domain"
  type        = bool
  default     = false
}

##############################
# SSH & Remote Backend Settings
##############################
variable "ssh_private_key_path" {
  description = "Path to the SSH private key used for connecting to EC2 instances"
  type        = string
  default     = "~/.ssh/id_rsa_github"
}

# Remote backend variables (if used) can be defined here.
# For example:
# variable "backend_bucket" { ... }
# variable "backend_key" { ... }
# variable "backend_region" { ... }
# variable "backend_encrypt" { ... }
# variable "backend_dynamodb_table" { ... }

##############################
# Docker & Application Variables
##############################

# New backend app configuration
variable "backend_image" {
  description = "Docker image for the backend app (e.g., Go Gin app)"
  type        = string
  default     = "rollg/go-gin-app"
}

variable "backend_container_name" {
  description = "Container name for the backend app"
  type        = string
  default     = "backend_app"
}

variable "backend_port" {
  description = "Port on which the backend app listens"
  type        = string
  default     = "8080"
}

variable "front_end_image" {
  description = "Docker image for the front-end app"
  type        = string
}

variable "front_end_container_name" {
  description = "Container name for the front-end app"
  type        = string
  default     = "front_end_app"
}

variable "front_end_port" {
  description = "Port on which the front-end app listens"
  type        = string
  default     = "3000"
}

variable "next_resend_api_key" {
  description = "The API key for Next Resend"
  type        = string
}

