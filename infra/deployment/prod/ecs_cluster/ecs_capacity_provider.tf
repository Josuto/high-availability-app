# The Capacity Provider (CP) manages the cluster's underlying EC2 infrastructure by telling the ECS how to manage the ASG scaling.
# It ensures there is always enough room for your containers to run, following the "Application-First" scaling mindset.
# NOTE: The name of the capacity provider cannot be prefixed with "aws" or "ecs".
resource "aws_ecs_capacity_provider" "ecs_capacity_provider" {
  name = "${var.environment}-${var.project_name}-ecs-capacity-provider"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = module.ecs_cluster.autoscaling_group_arn
    managed_termination_protection = lookup(var.managed_termination_protection_setting, var.environment)

    managed_scaling {
      status          = "ENABLED"
      target_capacity = lookup(var.ecs_max_utilisation, var.environment) # ECS aims to keep cluster utilization at the given percentage
    }
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name       = module.ecs_cluster.ecs_cluster_name
  capacity_providers = [aws_ecs_capacity_provider.ecs_capacity_provider.name]

  # Default strategy: use the EC2 Capacity Provider
  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.ecs_capacity_provider.name
    weight            = 1
    base              = 1 # Ensure at least 1 task runs on this capacity (good practice)
  }
}
