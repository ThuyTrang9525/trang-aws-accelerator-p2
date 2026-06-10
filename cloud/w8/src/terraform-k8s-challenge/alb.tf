resource "aws_lb_target_group" "tg" {

  name = "minikube-tg"

  port = 30080

  protocol = "HTTP"

  target_type = "instance"

  vpc_id = aws_vpc.main.id

  health_check {
    path = "/"
    port = "30080"
  }
}

resource "aws_lb_target_group_attachment" "attach" {

  target_group_arn = aws_lb_target_group.tg.arn

  target_id = aws_instance.minikube.id

  port = 30080
  depends_on = [aws_instance.minikube]
}

resource "aws_lb" "alb" {

  name               = "minikube-alb"
  load_balancer_type = "application"

  security_groups = [
    aws_security_group.alb.id
  ]

  subnets = [
    aws_subnet.public_a.id,
    aws_subnet.public_b.id
  ]
}
resource "aws_lb_listener" "http" {

  load_balancer_arn = aws_lb.alb.arn

  port = 80

  protocol = "HTTP"

  default_action {

    type = "forward"

    target_group_arn = aws_lb_target_group.tg.arn
  }
}