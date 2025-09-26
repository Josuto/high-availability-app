output "ecs_cluster_arn" {
  value = aws_ecs_cluster.ecs-cluster.arn
}

output "ecs_security_group_id" {
  value = aws_security_group.cluster.id
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.ecs-cluster.name
}

output "autoscaling_group_name" {
  value = aws_autoscaling_group.ecs-autoscaling-group.name
}