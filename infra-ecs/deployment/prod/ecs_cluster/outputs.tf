output "ecs_cluster_name" {
  description = "The name of the ECS cluster for service deployment"
  value       = module.ecs_cluster.ecs_cluster_name
}

output "ecs_cluster_arn" {
  description = "The ARN of the ECS cluster"
  value       = module.ecs_cluster.ecs_cluster_arn
}

output "ecs_capacity_provider_name" {
  description = "The name of the ECS capacity provider for auto-scaling"
  value       = aws_ecs_capacity_provider.ecs_capacity_provider.name
}
