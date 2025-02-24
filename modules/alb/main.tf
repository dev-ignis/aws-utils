resource "aws_lb" "app_lb" {
  name               = "${var.instance_name}-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.security_group_id]
  subnets            = var.lb_subnet_ids

  tags = {
    Name = "${var.instance_name}-lb"
  }
}

resource "aws_lb_target_group" "app_tg" {
  name        = "${var.instance_name}-tg"
  port        = tonumber(var.app_port)
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = var.vpc_id

  health_check {
    path     = "/"
    protocol = "HTTP"
  }

  tags = {
    Name = "${var.instance_name}-tg"
  }
}

resource "aws_lb_listener" "app_listener" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

resource "aws_lb_target_group_attachment" "app_attachment" {
  count            = length(var.instance_ids)
  target_group_arn = aws_lb_target_group.app_tg.arn
  target_id        = var.instance_ids[count.index]
  port             = tonumber(var.app_port)
}
