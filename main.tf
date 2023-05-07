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

  # tfsec:ignore:aws-ec2-no-public-ingress-sgr
  ingress {
    from_port   = 5000
    to_port     = 5000
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

resource "aws_eip" "fight_me_backend_eip" {
  instance = aws_instance.fight_me_backend.id
}
