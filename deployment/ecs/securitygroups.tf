resource "aws_security_group" "ecs-security-group" {
  vpc_id      = aws_vpc.main.id
  name        = "ecs"
  description = "Security group for the EC2 instances in the ECS cluster"

  egress { # Allow all traffic to the internet
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress { # Allow traffic from the ELB to the containers hosted at the EC2 instances
    from_port       = 3000
    to_port         = var.CONTAINER_PORT
    protocol        = "tcp"
    security_groups = [aws_security_group.dummy-app-elb-security-group.id]
  }

  ingress { # Allow SSH access to the EC2 instances
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "ecs"
  }
}

resource "aws_security_group" "dummy-app-elb-security-group" {
  vpc_id      = aws_vpc.main.id
  name        = "dummy-app-elb"
  description = "Security group for the ELB that serves the dummy app"
  egress { # Allow all traffic to the internet
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress { # Allow traffic from the internet to the ELB at port 80
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "dummy-app-elb"
  }
}

