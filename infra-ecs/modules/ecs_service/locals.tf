# Standard tags for cost tracking and resource management
locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Module      = "ecs_service"
    CreatedDate = timestamp()
  }
}
