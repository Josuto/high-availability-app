# ALB security group. It defines the ALB's "Front Door".
resource "aws_security_group" "alb" {
  name        = "${var.environment}-${var.project_name}-alb-sg"
  vpc_id      = var.vpc_id
  description = "The ALB security group."

  ingress { # Enable all inbound traffic to the ALB via HTTP
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress { # Enable all inbound traffic to the ALB via HTTPS
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress { # Defines what traffic can go out of the ALB (i.e., all of it). Crucially, this allows the ALB to initiate connections to your ECS tasks
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}
