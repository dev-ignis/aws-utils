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

resource "aws_instance" "my_ec2" {
  ami                    = var.ami
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = module.network.instance_subnet_id
  vpc_security_group_ids = [module.network.security_group_id]

  user_data = templatefile("${path.module}/user_data.sh", {
    docker_image       = var.docker_image
    dns_name           = var.dns_name
    certbot_email      = var.certbot_email
    app_port           = var.app_port
    app_container_name = var.app_container_name
  })

  tags = {
    Name = var.instance_name
  }

  lifecycle {
    ignore_changes = [user_data]
  }
}

module "alb" {
  count             = var.enable_load_balancer ? 1 : 0
  source            = "./modules/alb"
  instance_name     = var.instance_name
  app_port          = var.app_port
  vpc_id            = module.network.vpc_id
  lb_subnet_ids     = module.network.lb_subnet_ids
  security_group_id = module.network.security_group_id
  instance_id       = aws_instance.my_ec2.id
}
