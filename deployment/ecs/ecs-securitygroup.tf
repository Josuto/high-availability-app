# ECS cluster security group that acts as a firewall for your ECS cluster's compute resources. It controls all network traffic 
# to and from these compute resources.
resource "aws_security_group" "cluster" {
  name        = "${var.ECS_CLUSTER_NAME}-sg"
  vpc_id      = module.vpc.vpc_id
  description = "ECS cluster security group"
}

# Conditional inbound traffic rule that enables/disables SSH access to your ECS cluster's underlying instances/tasks with 
# a simple variable toggle.
resource "aws_security_group_rule" "cluster-allow-ssh" {
  count                    = "${ var.ECS_CLUSTER_ENABLE_SSH ? 1 : 0}"
  security_group_id        = aws_security_group.cluster.id # Apply rule to the cluster security group
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.allow-ssh.id # Only resources belonging to the source security group can initiate an SSH connection to the cluster's instances/tasks
}

# Rule that allows all outbound traffic from your ECS cluster's instances/tasks to anywhere on the internet. 
# FIXME: For highly secure environments, you might later restrict this to specific CIDR blocks or endpoints (e.g., VPC Endpoints for AWS services) 
# to follow the principle of least privilege.
resource "aws_security_group_rule" "cluster-egress" {
  security_group_id = aws_security_group.cluster.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}