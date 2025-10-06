resource "aws_security_group" "ecs_tasks" {
  name   = "ecs-tasks-sg"
  vpc_id = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Project = var.project_name
  }
}

# Rule to ensure that tasks only accept traffic from the ALB, not from the internet directly.
resource "aws_security_group_rule" "alb_to_tasks" {
  type                     = "ingress"
  from_port                = var.container_port
  to_port                  = var.container_port
  protocol                 = "tcp"
  source_security_group_id = var.alb_security_group_id # Only traffic coming from the ALB’s security group can get in
  security_group_id        = aws_security_group.ecs_tasks.id # Attaches the rule to the ECS tasks’ security group
}