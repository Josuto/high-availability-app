output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "public_subnets" {
  description = "The list of public subnet IDs for internet-facing resources"
  value       = module.vpc.public_subnets
}

output "private_subnets" {
  description = "The list of private subnet IDs for internal resources"
  value       = module.vpc.private_subnets
}
