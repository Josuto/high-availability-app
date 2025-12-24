output "node_group_id" {
  description = "EKS node group ID (format: cluster_name:node_group_name)"
  value       = aws_eks_node_group.main.id
}

output "node_group_name" {
  description = "EKS node group name (for use with AWS CLI commands)"
  value       = aws_eks_node_group.main.node_group_name
}

output "node_group_arn" {
  description = "Amazon Resource Name (ARN) of the EKS Node Group"
  value       = aws_eks_node_group.main.arn
}

output "node_group_status" {
  description = "Status of the EKS node group"
  value       = aws_eks_node_group.main.status
}

output "node_iam_role_arn" {
  description = "IAM role ARN of the EKS nodes"
  value       = aws_iam_role.eks_nodes.arn
}

output "node_iam_role_name" {
  description = "IAM role name of the EKS nodes"
  value       = aws_iam_role.eks_nodes.name
}
