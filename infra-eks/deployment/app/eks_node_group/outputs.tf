#####################################
# Node Group Outputs
#####################################

output "node_group_id" {
  description = "EKS Node Group ID (format: cluster_name:node_group_name)"
  value       = module.eks_node_group.node_group_id
}

output "node_group_name" {
  description = "EKS Node Group name (for use with AWS CLI commands)"
  value       = module.eks_node_group.node_group_name
}

output "node_group_arn" {
  description = "Amazon Resource Name (ARN) of the EKS Node Group"
  value       = module.eks_node_group.node_group_arn
}

output "node_group_status" {
  description = "Status of the EKS Node Group"
  value       = module.eks_node_group.node_group_status
}

output "node_iam_role_name" {
  description = "IAM role name for EKS nodes"
  value       = module.eks_node_group.node_iam_role_name
}

output "node_iam_role_arn" {
  description = "IAM role ARN for EKS nodes"
  value       = module.eks_node_group.node_iam_role_arn
}
