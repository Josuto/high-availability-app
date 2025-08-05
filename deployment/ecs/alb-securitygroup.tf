# ALB security group. It defines the ALB's "Front Door".
resource "aws_security_group" "alb" {
  name        = "${var.ALB_NAME}"
  vpc_id      = "${var.VPC_ID}"
  description = "${var.ALB_NAME}"

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
}

# Rule that defines what traffic can come into the ECS tasks/instances. Allow traffic if it originates from resources that are themselves 
# associated with the ALB security group. These two resources work hand-in-hand to establish a secure and functional network path for your 
# ECS-based application.
resource "aws_security_group_rule" "cluster-allow-alb" {
  security_group_id        = "${var.ECS_SG}"
  type                     = "ingress"
  from_port                = 32768
  to_port                  = 61000
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
}