resource "aws_security_group" "this" {
  name_prefix = "${var.name}-${var.environment}-cluster-ecs-"
  vpc_id      = data.aws_vpc.this.id

  tags = {
    Name      = "${var.name}-${var.environment}-cluster-ecs"
    Network   = var.vpc_name
    Terraform = "terraform-aws-cluster"
  }
}

resource "aws_vpc_security_group_ingress_rule" "this_this" {
  security_group_id = aws_security_group.this.id

  ip_protocol                  = "-1"
  referenced_security_group_id = aws_security_group.this.id

  tags = {
    Name      = "${var.name}-${var.environment}-cluster-ecs"
    Network   = var.vpc_name
    Terraform = "terraform-aws-cluster"
  }
}

resource "aws_vpc_security_group_ingress_rule" "this_lb" {
  security_group_id = aws_security_group.this.id

  ip_protocol                  = "-1"
  referenced_security_group_id = aws_security_group.lb.id

  tags = {
    Name      = "${var.name}-${var.environment}-cluster-ecs"
    Network   = var.vpc_name
    Terraform = "terraform-aws-cluster"
  }
}

resource "aws_vpc_security_group_egress_rule" "this_all" {
  security_group_id = aws_security_group.this.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"

  tags = {
    Name      = "${var.name}-${var.environment}-cluster-ecs"
    Network   = var.vpc_name
    Terraform = "terraform-aws-cluster"
  }
}

resource "aws_ecs_cluster" "this" {
  name = "${var.name}-${var.environment}"

  setting {
    name  = "containerInsights"
    value = "disabled"
  }
}

resource "aws_iam_role" "this" {
  assume_role_policy = data.aws_iam_policy_document.this_assume_role.json
  name               = "${var.name}-${var.environment}-cluster-ecs"
}

resource "aws_iam_role_policy_attachment" "service_role" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
  role       = aws_iam_role.this.name
}

resource "aws_iam_instance_profile" "this" {
  name = "${var.name}-${var.environment}-cluster-ecs"
  role = aws_iam_role.this.name
}

resource "aws_launch_template" "this" {
  name_prefix   = "${var.name}-${var.environment}-cluster-ecs-"
  image_id      = data.aws_ami.this.id
  instance_type = var.instance_type
  key_name      = "${var.name}-${var.environment}-cluster-ecs"

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      delete_on_termination = true
      volume_size           = 50
      volume_type           = "gp2"
    }
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.this.name
  }

  instance_market_options {
    market_type = var.market_type
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups = [
      aws_security_group.this.id,
      data.aws_security_group.this_private.id
    ]
  }

  user_data = base64encode(templatefile("${path.module}/user_data.tpl", {
    cluster_name = aws_ecs_cluster.this.name
  }))
}

resource "aws_autoscaling_group" "this" {
  desired_capacity = 1
  max_size         = 1
  min_size         = 1

  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
    triggers = ["tag"]

    preferences {
      min_healthy_percentage = 50
    }
  }

  vpc_zone_identifier = data.aws_subnets.this_private.ids

  tag {
    key                 = "AmazonECSManaged"
    propagate_at_launch = true
    value               = "true"
  }
}

resource "aws_ecs_capacity_provider" "this" {
  name = "${var.name}-${var.environment}"

  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.this.arn

    managed_scaling {
      status = "DISABLED"
    }
  }

  depends_on = [
    aws_security_group.lb,
  ]
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  capacity_providers = [aws_ecs_capacity_provider.this.name]
  cluster_name       = aws_ecs_cluster.this.name

  default_capacity_provider_strategy {
    base              = 1
    capacity_provider = aws_ecs_capacity_provider.this.name
    weight            = 100
  }
}
