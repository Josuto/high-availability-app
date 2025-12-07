# EKS Cluster Module
# Creates an EKS cluster with necessary IAM roles and security groups
# Equivalent to ECS Cluster but for Kubernetes

resource "aws_eks_cluster" "main" {
  name     = local.cluster_name
  role_arn = aws_iam_role.eks_cluster.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = concat(var.vpc_private_subnets, var.vpc_public_subnets)
    endpoint_private_access = true
    endpoint_public_access  = var.endpoint_public_access[var.environment]
    public_access_cidrs     = var.endpoint_public_access[var.environment] ? ["0.0.0.0/0"] : []
    security_group_ids      = [aws_security_group.eks_cluster.id]
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  # Encryption configuration for secrets
  encryption_config {
    provider {
      key_arn = var.kms_key_arn != "" ? var.kms_key_arn : null
    }
    resources = ["secrets"]
  }

  tags = local.common_tags

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_iam_role_policy_attachment.eks_vpc_resource_controller,
    aws_cloudwatch_log_group.eks_cluster
  ]
}

# CloudWatch Log Group for EKS cluster logs
resource "aws_cloudwatch_log_group" "eks_cluster" {
  name              = "/aws/eks/${local.cluster_name}/cluster"
  retention_in_days = var.log_retention_days[var.environment]

  tags = local.common_tags
}
