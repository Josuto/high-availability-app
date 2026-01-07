#####################################
# Local Variables
#####################################

locals {
  # Common tags for all resources
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Module      = "k8s_app"
    CreatedDate = timestamp()
  }

  # Common labels for Kubernetes resources
  common_labels = {
    "app.kubernetes.io/name"       = var.app_name
    "app.kubernetes.io/instance"   = "${var.app_name}-${var.environment}"
    "app.kubernetes.io/version"    = var.image_tag
    "app.kubernetes.io/component"  = "application"
    "app.kubernetes.io/part-of"    = var.project_name
    "app.kubernetes.io/managed-by" = "terraform"
    "environment"                  = var.environment
  }
}
