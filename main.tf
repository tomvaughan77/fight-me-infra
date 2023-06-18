terraform {
  backend "s3" {
    bucket         = "fight-me-infra-terraform-state-bucket"
    key            = "terraform.tfstate"
    region         = "eu-west-2"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = "eu-west-2"
}

resource "aws_ecs_cluster" "fight_me_backend_cluster" {
  name = "fight-me-backend-cluster"
}

resource "aws_ecs_task_definition" "fight_me_backend_task" {
  family                   = "fight-me-backened-task"
  container_definitions    = <<DEFINITION
  [
    {
      "name": "my-first-task",
      "image": "terminalhavok97/fight-me-backend:latest",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 5000,
          "hostPort": 5000
        }
      ],
      "memory": 512,
      "cpu": 256,
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/my-first-task",
          "awslogs-region": "eu-west-2",
          "awslogs-stream-prefix": "ecs"
        }
      },
      "healthCheck": {
        "command": ["CMD-SHELL","curl -f http://0.0.0.0:5000/health || exit 1"],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 0
      }
    }
  ]
  DEFINITION
  requires_compatibilities = ["EC2"]
  network_mode             = "bridge" # Change from awsvpc to bridge
  memory                   = 512
  cpu                      = 256
  execution_role_arn       = aws_iam_role.ecsTaskExecutionRole.arn
}

resource "aws_iam_role" "ecsTaskExecutionRole" {
  name               = "ecsTaskExecutionRole"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ecsTaskExecutionRole_policy" {
  role       = aws_iam_role.ecsTaskExecutionRole.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_lb" "fight_me_backend_lb" {
  name               = "fight-me-backend-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  subnets            = ["${aws_default_subnet.default_subnet_a.id}", "${aws_default_subnet.default_subnet_b.id}", "${aws_default_subnet.default_subnet_c.id}"]
}

resource "aws_lb_target_group" "fight_me_backend_tg" {
  name     = "fight-me-backend-tg"
  port     = 5000
  protocol = "HTTP"
  vpc_id   = aws_default_vpc.default_vpc.id

  health_check {
    interval            = 30
    path                = "/health"
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }
}

resource "aws_lb_listener" "fight_me_backend_listener" {
  load_balancer_arn = aws_lb.fight_me_backend_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.fight_me_backend_tg.arn
  }
}

resource "aws_ecs_service" "fight_me_backend_service" {
  name            = "fight-me-backend-service"
  cluster         = aws_ecs_cluster.fight_me_backend_cluster.id
  task_definition = aws_ecs_task_definition.fight_me_backend_task.arn
  launch_type     = "EC2"
  desired_count   = 1

  load_balancer {
    target_group_arn = aws_lb_target_group.fight_me_backend_tg.arn
    container_name   = "my-first-task"
    container_port   = 5000
  }
}

resource "aws_security_group" "lb_sg" {
  name        = "lb_sg"
  description = "Allow inbound traffic"
  vpc_id      = aws_default_vpc.default_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # New rule to allow inbound traffic on port 5000
  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_default_vpc" "default_vpc" {
}

resource "aws_default_subnet" "default_subnet_a" {
  availability_zone = "eu-west-2a"
}

resource "aws_default_subnet" "default_subnet_b" {
  availability_zone = "eu-west-2b"
}

resource "aws_default_subnet" "default_subnet_c" {
  availability_zone = "eu-west-2c"
}

resource "aws_cloudwatch_log_group" "ecs_log_group" {
  name              = "/ecs/my-first-task"
  retention_in_days = 14
}

resource "aws_iam_role_policy_attachment" "ecsTaskExecutionRole_cloudwatch" {
  role       = aws_iam_role.ecsTaskExecutionRole.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

data "aws_ami" "latest_ecs_optimized" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-*-x86_64-ebs"]
  }

  owners = ["amazon"]
}

# ECS Instance Security Group
resource "aws_security_group" "ecs_instance_sg" {
  name        = "ecs_instance_sg"
  description = "Allow inbound traffic from ALB"
  vpc_id      = aws_default_vpc.default_vpc.id

  ingress {
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.lb_sg.id] # Allows traffic from the ALB to the EC2 instance
  }

  # This will allow all outbound traffic. Modify to meet your needs.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ECS Instance
resource "aws_instance" "ecs_instance" {
  ami                  = data.aws_ami.latest_ecs_optimized.id
  instance_type        = "t2.micro"
  iam_instance_profile = aws_iam_instance_profile.ecs_instance_profile.name

  vpc_security_group_ids = [aws_security_group.ecs_instance_sg.id] # Associates the new security group with the EC2 instance

  user_data = <<-EOF
              #!/bin/bash
              echo ECS_CLUSTER=${aws_ecs_cluster.fight_me_backend_cluster.name} >> /etc/ecs/ecs.config
              EOF

  tags = {
    Name = "ECS Instance - ${aws_ecs_cluster.fight_me_backend_cluster.name}"
  }
}

resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "ecs-instance-profile"
  role = aws_iam_role.ecs_instance_role.name
}

resource "aws_iam_role" "ecs_instance_role" {
  name = "ecs-instance-role"

  assume_role_policy = <<EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Principal": {
          "Service": "ec2.amazonaws.com"
        },
        "Effect": "Allow",
        "Sid": ""
      }
    ]
  }
  EOF
}

resource "aws_iam_role_policy_attachment" "ecs_instance_role_policy_attach" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_lb_listener_rule" "health_check" {
  listener_arn = aws_lb_listener.fight_me_backend_listener.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.fight_me_backend_tg.arn
  }

  condition {
    path_pattern {
      values = ["/health"]
    }
  }
}
