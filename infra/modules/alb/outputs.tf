output "alb_target_group_id" {
  value = aws_alb_target_group.ecs-service.id
}

output "alb_dns_name" {
  value = aws_alb.alb.dns_name
}

output "alb_arn_suffix" {
  value = aws_alb.alb.arn_suffix
}

output "alb_target_group_arn_suffix" {
  value = aws_alb_target_group.ecs-service.arn_suffix
}

output "alb_security_group_id" {
  value = aws_security_group.alb.id
}

output "alb_hosted_zone_id" {
  value = aws_alb.alb.zone_id
}
