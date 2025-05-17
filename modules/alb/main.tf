resource "aws_lb" "app_lb" {
  name               = "${var.instance_name}-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.security_group_id]
  subnets            = var.lb_subnet_ids

  tags = {
    Name        = "${var.instance_name}-lb"
    Environment = var.environment
  }
}

resource "aws_lb_target_group" "app_tg" {
  name        = "${var.instance_name}-tg"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = var.vpc_id

  health_check {
    path                = "/health"
    protocol            = "HTTP"
    interval            = 30
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  tags = {
    Name        = "${var.instance_name}-tg"
    Environment = var.environment
  }
}

resource "aws_lb_listener" "app_listener" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Host-based routing rule for the staging domain
resource "aws_lb_listener_rule" "staging_rule" {
  listener_arn = aws_lb_listener.app_listener.arn
  priority     = 100

  condition {
    host_header {
      values = [var.staging_api_dns_name]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

resource "aws_lb_target_group_attachment" "app_attachment" {
  count            = length(var.instance_ids)
  target_group_arn = aws_lb_target_group.app_tg.arn
  target_id        = var.instance_ids[count.index]
  port             = 80
}

# Outputs for referencing the ALB in the root module
output "lb_dns_name" {
  description = "The DNS name of the load balancer"
  value       = aws_lb.app_lb.dns_name
}

output "lb_zone_id" {
  description = "The hosted zone ID associated with the load balancer"
  value       = aws_lb.app_lb.zone_id
}
