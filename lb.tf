resource "aws_security_group" "lb" {
  name_prefix = "${var.name}-${var.environment}-cluster-ecs-"
  vpc_id      = data.aws_vpc.this.id

  tags = {
    Name      = "${var.name}-${var.environment}-cluster-ecs"
    Network   = var.vpc_name
    Terraform = "terraform-aws-cluster"
  }
}

resource "aws_vpc_security_group_ingress_rule" "lb_http" {
  security_group_id = aws_security_group.lb.id

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 80
  ip_protocol = "tcp"
  to_port     = 80

  tags = {
    Name      = "${var.name}-${var.environment}-cluster-ecs"
    Network   = var.vpc_name
    Terraform = "terraform-aws-cluster"
  }
}

resource "aws_vpc_security_group_egress_rule" "lb_all" {
  security_group_id = aws_security_group.lb.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"

  tags = {
    Name      = "${var.name}-${var.environment}-cluster-ecs"
    Network   = var.vpc_name
    Terraform = "terraform-aws-cluster"
  }
}

resource "aws_lb" "this_public" {
  enable_deletion_protection = false
  idle_timeout               = 300
  internal                   = false
  load_balancer_type         = "application"
  preserve_host_header       = false
  security_groups            = [aws_security_group.lb.id]
  subnets                    = data.aws_subnets.this_public.ids

  tags = {
    Name      = "${var.name}-${var.environment}-cluster-ecs"
    Network   = var.vpc_name
    Terraform = "terraform-aws-cluster"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this_public.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "application/json"
      message_body = jsonencode({ message = "not found" })
      status_code  = "404"
    }
  }

  tags = {
    Name      = "${var.name}-${var.environment}-cluster-ecs"
    Network   = var.vpc_name
    Terraform = "terraform-aws-cluster"
  }
}

# resource "aws_lb_listener" "http" {
#   load_balancer_arn = aws_lb.this.arn
#   port              = "80"
#   protocol          = "HTTP"
#   default_action {
#     type = "redirect"
#     redirect {
#       port        = "443"
#       protocol    = "HTTPS"
#       status_code = "HTTP_301"
#     }
#   }
# }

# resource "aws_lb_listener" "https" {
#   certificate_arn = "<insert your certificate ARN here>"
#   load_balancer_arn = aws_lb.this.arn
#   port       = "443"
#   protocol   = "HTTPS"
#   ssl_policy = "ELBSecurityPolicy-2016-08"
#   default_action {
#     type = "fixed-response"
#     fixed_response {
#       content_type = "application/json"
#       message_body = jsonencode({ message = "not found" })
#       status_code  = "404"
#     }
#   }
# }

resource "aws_lb_target_group" "service" {
  deregistration_delay              = 60
  load_balancing_cross_zone_enabled = true
  port                              = 80
  protocol                          = "HTTP"
  vpc_id                            = data.aws_vpc.this.id

  tags = {
    Cluster   = "${var.name}-${var.environment}"
    Name      = "fem-eci-service-${var.environment}"
    Network   = var.vpc_name
    Terraform = "terraform-aws-cluster"
  }
}

resource "aws_lb_listener_rule" "service" {
  listener_arn = aws_lb_listener.http.arn

  action {
    target_group_arn = aws_lb_target_group.service.arn
    type             = "forward"
  }

  condition {
    host_header {
      values = ["${var.name}.${var.domain}"]
    }
  }
}
