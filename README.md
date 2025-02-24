# Base Terraform AWS Infrastructure

This repository provides a base Terraform configuration to create a basic AWS infrastructure, including:
- A custom VPC with DNS support
- A public subnet
- An Internet Gateway and associated route table
- A security group for SSH, HTTP, and HTTPS access
- An EC2 instance that runs a Docker container with NGINX and Certbot
- A Route53 DNS record for the EC2 instance

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) 0.12+
- AWS credentials with sufficient permissions
- An AWS key pair for SSH access

## How to Use

1. **Clone the repository:**
   ```bash
   git clone https://github.com/dev-ignis/aws-docker-deployment.git
   cd aws-docker-deployment
