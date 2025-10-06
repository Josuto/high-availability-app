# ECS cluster security group that acts as a firewall for your ECS cluster's compute resources. It controls all network traffic 
# to and from these compute resources.
resource "aws_security_group" "cluster" {
  name        = "${var.cluster_name}-sg"
  vpc_id      = var.vpc_id
  description = "ECS cluster security group"

  tags = {
    Project = var.project_name
  }
}

# Rule that allows all outbound traffic from your ECS cluster's instances/tasks to anywhere on the internet. 
resource "aws_security_group_rule" "cluster-egress" {
  security_group_id = aws_security_group.cluster.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}