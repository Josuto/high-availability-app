output "alb_target_group_id" {
  description = "The ID of the ALB target group used for ECS service routing"
  value       = aws_alb_target_group.ecs_service.id
}

output "alb_dns_name" {
  description = "The DNS name of the Application Load Balancer"
  value       = aws_alb.alb.dns_name
}

output "alb_arn_suffix" {
  description = "The ARN suffix of the ALB for use in CloudWatch metrics"
  value       = aws_alb.alb.arn_suffix
}

output "alb_target_group_arn_suffix" {
  description = "The ARN suffix of the target group for use in CloudWatch metrics"
  value       = aws_alb_target_group.ecs_service.arn_suffix
}

output "alb_security_group_id" {
  description = "The ID of the security group attached to the ALB"
  value       = aws_security_group.alb.id
}

output "alb_hosted_zone_id" {
  description = "The Route53 hosted zone ID of the ALB for alias records"
  value       = aws_alb.alb.zone_id
}
