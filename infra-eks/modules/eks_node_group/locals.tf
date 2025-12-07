# Standard tags for cost tracking and resource management
locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Module      = "eks_node_group"
    CreatedDate = timestamp()
  }
}
