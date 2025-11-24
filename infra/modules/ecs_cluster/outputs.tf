output "ecs_cluster_name" {
  value = aws_ecs_cluster.ecs-cluster.name
}

output "ecs_cluster_arn" {
  value = aws_ecs_cluster.ecs-cluster.arn
}

output "autoscaling_group_arn" {
  value = aws_autoscaling_group.ecs-autoscaling-group.arn
}
