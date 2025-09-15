# Output the ECR repository URL to consume in the GitHub Actions pipeline
output "alb_target_group_id" {
  value = aws_alb_target_group.ecs-service.id
}

output "alb_dns_name" {
  value = aws_alb.alb.dns_name
}

output "alb_hosted_zone_id" {
  value = aws_alb.alb.zone_id
}