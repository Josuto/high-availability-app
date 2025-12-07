# Standard tags for cost tracking and resource management
locals {
  # Cluster naming
  cluster_name = "${var.environment}-${var.project_name}-ecs-cluster"

  # Common tags for all resources
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Module      = "ecs_cluster"
    CreatedDate = timestamp()
  }

  # Tags for EC2 instances with Name tag
  instance_tags = merge(
    local.common_tags,
    {
      Name = "ecs-ec2-container"
    }
  )

  # Template for EC2 instance bootstrapping
  template = templatefile("${path.module}/templates/ec2-instance-init.tpl", {
    ecs_cluster_name = local.cluster_name
  })
}
