# ALB security group. It defines the ALB's "Front Door".
resource "aws_security_group" "alb" {
  name        = "my-alb-sg"
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
    Project = var.project_name
  }
}

# Rule that defines what traffic can come into the ECS tasks/instances. It secures your backend ECS tasks by allowing incoming traffic only from 
# your trusted ALB, ensuring your containers aren't directly exposed to the internet on their dynamic ports
resource "aws_security_group_rule" "cluster-allow-alb" {
  security_group_id        = var.ecs_security_group_id
  type                     = "ingress"
  from_port                = 32768 # Assign a dynamic port to each container running on an EC2 instance. Such ports are picked from 32768-61000
  to_port                  = 61000
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
}