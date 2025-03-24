provider "aws" {
  region = var.region
}

module "network" {
  source             = "./modules/network"
  instance_name      = var.instance_name
  vpc_cidr           = var.vpc_cidr
  subnet_cidrs       = var.subnet_cidrs
  availability_zones = var.availability_zones
  app_port           = var.app_port
}

module "dynamodb" {
  source       = "./modules/dynamodb"
  table_name   = "${var.instance_name}-table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "Id"
  hash_key_type = "S"
  tags = {
    Environment = var.environment
    Name        = "${var.instance_name}-dynamodb"
  }
}

# Create two EC2 instances, one in each subnet provided by the network module
resource "aws_instance" "my_ec2" {
  count                  = 2
  ami                    = var.ami
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = module.network.lb_subnet_ids[count.index]
  vpc_security_group_ids = [module.network.security_group_id]

  user_data = templatefile("${path.module}/user_data.sh.tpl", {
    docker_image               = var.docker_image         // May no longer be used if only using backend_image & front_end_image
    backend_image              = var.backend_image
    front_end_image            = var.front_end_image
    backend_container_name     = var.backend_container_name
    front_end_container_name   = var.front_end_container_name
    backend_port               = var.backend_port
    front_end_port             = var.front_end_port
    dns_name                   = var.dns_name
    certbot_email              = var.certbot_email
#    front_end_repo             = var.front_end_repo      // Only if you’re cloning/building instead of using a Docker image
#    front_end_branch           = var.front_end_branch    // Same as above
  })

  tags = {
    Name = "${var.instance_name}-${count.index}"
  }

  lifecycle {
    ignore_changes = [user_data]
  }
}

# Pass required values to the ALB module, including the staging DNS name.
module "alb" {
  count             = var.enable_load_balancer ? 1 : 0
  source            = "./modules/alb"
  instance_name     = var.instance_name
  app_port          = var.app_port
  vpc_id            = module.network.vpc_id
  lb_subnet_ids     = module.network.lb_subnet_ids
  security_group_id = module.network.security_group_id
  instance_ids      = aws_instance.my_ec2[*].id
  staging_api_dns_name = var.staging_api_dns_name
}
