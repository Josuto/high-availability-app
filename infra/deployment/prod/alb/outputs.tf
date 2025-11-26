output "alb_target_group_id" {
  description = "The ID of the ALB target group for ECS service integration"
  value       = module.alb.alb_target_group_id
}

output "alb_dns_name" {
  description = "The DNS name of the ALB for routing traffic"
  value       = module.alb.alb_dns_name
}

output "alb_hosted_zone_id" {
  description = "The Route53 hosted zone ID of the ALB for creating alias records"
  value       = module.alb.alb_hosted_zone_id
}

output "alb_arn_suffix" {
  description = "The ARN suffix of the ALB for CloudWatch metrics"
  value       = module.alb.alb_arn_suffix
}

output "alb_security_group_id" {
  description = "The ID of the ALB security group for network access control"
  value       = module.alb.alb_security_group_id
}

output "alb_target_group_arn_suffix" {
  description = "The ARN suffix of the target group for CloudWatch metrics"
  value       = module.alb.alb_target_group_arn_suffix
}
