# The Capacity Provider (CP) manages the cluster's underlying EC2 infrastructure by telling the ECS how to manage the ASG scaling. 
# It ensures there is always enough room for your containers to run, following the "Application-First" scaling mindset. 
resource "aws_ecs_capacity_provider" "ecs_capacity_provider" {
  name = "app_ecs_capacity_provider"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = module.ecs_cluster.autoscaling_group_arn # aws_autoscaling_group.ecs_asg.arn
    managed_termination_protection = "ENABLED" # Prevent terminating instances with running tasks

    managed_scaling {
      status          = "ENABLED"
      target_capacity = 75 # ECS aims to keep cluster utilization at 75%
    }
  }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name       = module.ecs_cluster.ecs_cluster_name # aws_ecs_cluster.main.name
  capacity_providers = [aws_ecs_capacity_provider.ecs_capacity_provider.name]
  
  # Default strategy: use the EC2 Capacity Provider
  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.ecs_capacity_provider.name
    weight            = 1
    base              = 1 # Ensure at least 1 task runs on this capacity (good practice)
  }
}