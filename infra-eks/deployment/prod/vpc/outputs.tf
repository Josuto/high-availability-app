output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_private_subnets" {
  description = "The list of private subnet IDs for internal resources (EKS nodes)"
  value       = module.vpc.private_subnets
}

output "vpc_public_subnets" {
  description = "The list of public subnet IDs for internet-facing resources (ALB)"
  value       = module.vpc.public_subnets
}

# Legacy output names for backwards compatibility
output "private_subnets" {
  description = "Alias for vpc_private_subnets"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "Alias for vpc_public_subnets"
  value       = module.vpc.public_subnets
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "nat_gateway_ids" {
  description = "List of NAT Gateway IDs"
  value       = module.vpc.natgw_ids
}
