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

# ALB resources are created only if enable_load_balancer is true
resource "aws_lb" "app_lb" {
  count              = var.enable_load_balancer ? 1 : 0
  name               = "${var.instance_name}-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [module.network.security_group_id]
  subnets            = module.network.lb_subnet_ids

  tags = {
    Name = "${var.instance_name}-lb"
  }
}

resource "aws_lb_target_group" "app_tg" {
  count       = var.enable_load_balancer ? 1 : 0
  name        = "${var.instance_name}-tg"
  port        = tonumber(var.app_port)
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = module.network.vpc_id

  health_check {
    path     = "/"
    protocol = "HTTP"
  }

  tags = {
    Name = "${var.instance_name}-tg"
  }
}

resource "aws_lb_listener" "app_listener" {
  count             = var.enable_load_balancer ? 1 : 0
  load_balancer_arn = aws_lb.app_lb[0].arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg[0].arn
  }
}

resource "aws_lb_target_group_attachment" "app_attachment" {
  count            = var.enable_load_balancer ? 1 : 0
  target_group_arn = aws_lb_target_group.app_tg[0].arn
  target_id        = aws_instance.my_ec2.id
  port             = tonumber(var.app_port)
}
