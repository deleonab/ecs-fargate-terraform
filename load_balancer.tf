resource "aws_lb" "cluster_lb2" {
  name               = "cluster-alb"
  subnets            = aws_subnet.public[*].id
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb2.id]

  tags = {
    Application = "devops-uncut-webpage"
  }
}

resource "aws_lb_listener" "https_forward" {
  load_balancer_arn = aws_lb.cluster_lb2.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs-fargate-TG.arn
  }
}

resource "aws_lb_target_group" "ecs-fargate-TG" {
  name        = "ecs-fargate-TG"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    healthy_threshold   = "3"
    interval            = "90"
    protocol            = "HTTP"
    matcher             = "200-299"
    timeout             = "20"
    path                = "/"
    unhealthy_threshold = "2"
  }
}
