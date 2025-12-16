# EKS Cluster Module
# Creates an EKS cluster with necessary IAM roles and security groups
# Equivalent to ECS Cluster but for Kubernetes

# trivy:ignore:AVD-AWS-0039 - Encryption is optional and controlled by kms_key_arn variable. AWS uses managed encryption by default.
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

  # Encryption configuration for secrets (only when KMS key is provided)
  dynamic "encryption_config" {
    for_each = var.kms_key_arn != "" ? [1] : []
    content {
      provider {
        key_arn = var.kms_key_arn
      }
      resources = ["secrets"]
    }
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
