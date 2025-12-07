# Standard tags for cost tracking and resource management
locals {
  # Cluster naming
  cluster_name = "${var.environment}-${var.project_name}-eks-cluster"

  # Common tags for all resources
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Module      = "eks_cluster"
    CreatedDate = timestamp()
  }
}
