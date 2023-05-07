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

resource "aws_security_group" "fight_me_backend_sg" {
  name        = "fight_me_backend_sg"
  description = "Allow inbound traffic for Socket.IO server"

  # tfsec:ignore:aws-ec2-no-public-ingress-sgr
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow inbound http/websocket traffic to server on port 80"
  }

  # tfsec:ignore:aws-ec2-no-public-ingress-sgr
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow inbound http/websocket traffic to server on port 8080"
  }

  # tfsec:ignore:aws-ec2-no-public-egress-sgr
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow outbound http/websocket traffic from server"
  }
}

resource "aws_iam_role" "cloudwatch_logs_role" {
  name = "cloudwatch_logs_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cloudwatch_logs_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
  role       = aws_iam_role.cloudwatch_logs_role.name
}

resource "aws_cloudwatch_log_group" "fight_me_log_group" {
  name = "/fight-me-backend"

  retention_in_days = 30
}

resource "aws_cloudwatch_log_stream" "fight_me_log_stream" {
  name           = "fight-me-backend-${aws_instance.fight_me_backend.id}"
  log_group_name = aws_cloudwatch_log_group.fight_me_log_group.name
}

resource "aws_cloudwatch_log_resource_policy" "allow_instance_logs" {
  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "logs:PutLogEvents"
        Resource  = aws_cloudwatch_log_group.fight_me_log_group.arn
      }
    ]
  })

  policy_name = "allow_instance_logs"
}

resource "aws_cloudwatch_agent_configuration" "fight_me_cw_config" {
  name = "fight-me-backend"
  configuration = jsonencode({
    agent = {
      run_as_user = "root"
    },
    logs = {
      logs_collected = {
        files = {
          collect_list = [
            {
              file_path        = "/var/log/fight-me-backend.log"
              log_group_name   = aws_cloudwatch_log_group.fight_me_log_group.name
              log_stream_name  = aws_cloudwatch_log_stream.fight_me_log_stream.name
              timezone         = "UTC"
              timestamp_format = "%Y-%m-%dT%H:%M:%S.%f"
            }
          ]
        }
      },
      log_stream_name      = "${aws_instance.fight_me_backend.id}"
      force_flush_interval = 15
    }
  })
}

resource "aws_cloudwatch_agent_instance_profile" "fight_me_cw_instance_profile" {
  instance_profile_name = "cloudwatch_logs_instance_profile"
  role_arn              = aws_iam_role.cloudwatch_logs_role.arn
}

resource "aws_instance" "fight_me_backend" {
  ami           = "ami-0cd8ad123effa531a" # Amazon Linux 3 for eu-west-2
  instance_type = "t2.micro"              # Free tier eligible instance type

  vpc_security_group_ids = [aws_security_group.fight_me_backend_sg.id]

  root_block_device {
    encrypted = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  user_data = <<EOF
#!/bin/bash
yum update -y
yum install -y python3 python3-pip git

# Install CloudWatch Logs agent
curl https://s3.amazonaws.com/aws-cloudwatch/downloads/latest/awslogs-agent-setup.py -O
python3 awslogs-agent-setup.py -n -r eu-west-2 -c /etc/awslogs/awslogs.conf

# Install Poetry
curl -sSL https://install.python-poetry.org | python3 -

# Clone your project repository
git clone --depth=1 https://github.com/tomvaughan77/fight-me-backend /home/ec2-user/fight-me-backend

# Set environment variables
export PATH=$PATH:/root/.local/bin

# Navigate to the project directory and install dependencies
cd /home/ec2-user/fight-me-backend
poetry install

# Run your Socket.IO server (Replace <your_main_file> with the name of your main Python file)
nohup python fight_me_backend/main.py &
EOF

  tags = {
    Name = "fight-me-backend"
  }
}
