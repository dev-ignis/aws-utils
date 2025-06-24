resource "aws_lb" "app_lb" {
  name               = "${var.instance_name}-${var.environment}-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.security_group_id]
  subnets            = var.lb_subnet_ids

  tags = {
    Name        = "${var.instance_name}-${var.environment}-lb"
    Environment = var.environment
  }
}

resource "aws_lb_target_group" "app_tg" {
  name        = "${var.instance_name}-${var.environment}-tg"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = var.vpc_id

  health_check {
    path                = "/health"
    protocol            = "HTTP"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = {
    Name        = "${var.instance_name}-${var.environment}-tg"
    Environment = var.environment
  }
}

# Blue-Green Target Groups for zero-downtime deployments
resource "aws_lb_target_group" "blue_tg" {
  name        = "${var.instance_name}-${var.environment}-blue-tg"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = var.vpc_id

  health_check {
    path                = "/health"
    protocol            = "HTTP"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = {
    Name        = "${var.instance_name}-${var.environment}-blue-tg"
    Environment = var.environment
    BlueGreen   = "blue"
  }
}

resource "aws_lb_target_group" "green_tg" {
  name        = "${var.instance_name}-${var.environment}-green-tg"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = var.vpc_id

  health_check {
    path                = "/health"
    protocol            = "HTTP"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = {
    Name        = "${var.instance_name}-${var.environment}-green-tg"
    Environment = var.environment
    BlueGreen   = "green"
  }
}

# HTTP Listener for port 80 that redirects to HTTPS
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
      host        = "#{host}"
      path        = "/#{path}"
      query       = "#{query}"
    }
  }

  lifecycle {
    create_before_destroy = true
    replace_triggered_by  = [aws_acm_certificate.main]
  }

  depends_on = [aws_acm_certificate_validation.main]
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

