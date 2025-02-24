provider "aws" {
  region = var.region
}

module "network" {
  source            = "./modules/network"
  instance_name     = var.instance_name
  vpc_cidr          = var.vpc_cidr
  subnet_cidr       = var.subnet_cidr
  availability_zone = var.availability_zone
}

# Create the EC2 instance in our new VPC and public subnet using network module outputs
resource "aws_instance" "my_ec2" {
  ami                    = var.ami
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = module.network.subnet_id
  vpc_security_group_ids = [module.network.security_group_id]

  # Load the user_data from an external file using templatefile().
  user_data = templatefile("${path.module}/user_data.sh", {
    docker_image        = var.docker_image
    dns_name            = var.dns_name
    certbot_email       = var.certbot_email
    app_port            = var.app_port
    app_container_name  = var.app_container_name
  })

  tags = {
    Name = var.instance_name
  }

  lifecycle {
    ignore_changes = [user_data]
  }
}
