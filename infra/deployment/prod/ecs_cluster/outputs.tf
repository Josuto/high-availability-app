output "ecs_cluster_name" {
  value = module.ecs_cluster.ecs_cluster_name
}

output "ecs_cluster_arn" {
  value = module.ecs_cluster.ecs_cluster_arn
}

output "ecs_security_group_id" {
  value = module.ecs_cluster.ecs_security_group_id
}

output "autoscaling_group_name" {
  value = module.ecs_cluster.autoscaling_group_name
}

output "ecs_capacity_provider_name" {
  value = aws_ecs_capacity_provider.ecs_capacity_provider.name
}
