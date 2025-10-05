output "ecs_cluster_name" {
  value = module.ecs_cluster.ecs_cluster_name
}

output "ecs_cluster_arn" {
  value = module.ecs_cluster.ecs_cluster_arn
}

output "ecs_capacity_provider_name" {
  value = aws_ecs_capacity_provider.ecs_capacity_provider.name
}
