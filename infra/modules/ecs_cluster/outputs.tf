output "ecs_cluster_name" {
  description = "The name of the ECS cluster"
  value       = aws_ecs_cluster.ecs_cluster.name
}

output "ecs_cluster_arn" {
  description = "The ARN of the ECS cluster"
  value       = aws_ecs_cluster.ecs_cluster.arn
}

output "autoscaling_group_arn" {
  description = "The ARN of the Auto Scaling Group managing the ECS cluster instances"
  value       = aws_autoscaling_group.ecs_autoscaling_group.arn
}
