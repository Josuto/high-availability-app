#####################################
# Data Sources - Remote State
#####################################

# Reference the ECR remote state
data "terraform_remote_state" "ecr" {
  backend = "s3"

  config = {
    bucket = var.state_bucket_name
    key    = "deployment/ecr/terraform.tfstate"
    # region = "eu-west-1"  # When omitted, region of the provider is used
  }
}

# Reference the EKS cluster remote state
data "terraform_remote_state" "eks_cluster" {
  backend = "s3"

  config = {
    bucket = var.state_bucket_name
    key    = "deployment/prod/eks_cluster/terraform.tfstate"
    # region = "eu-west-1"  # When omitted, region of the provider is used
  }
}

# Reference the ACM certificate remote state (optional for HTTPS)
data "terraform_remote_state" "acm" {
  backend = "s3"

  config = {
    bucket = var.state_bucket_name
    key    = "deployment/ssl/terraform.tfstate"
    # region = "eu-west-1"  # When omitted, region of the provider is used
  }
}

#####################################
# Kubernetes Application Deployment
#####################################

module "k8s_app" {
  source = "../../../modules/k8s_app_deployment"

  # Project Configuration
  project_name = var.project_name
  environment  = var.environment

  # Application Configuration
  app_name           = var.app_name
  namespace          = var.namespace
  ecr_repository_url = data.terraform_remote_state.ecr.outputs.ecr_repository_url
  image_tag          = var.image_tag
  container_port     = var.container_port
  health_check_path  = var.health_check_path

  # Deployment Configuration
  replica_count = var.replica_count

  # Resource Configuration
  memory_request = var.memory_request
  memory_limit   = var.memory_limit
  cpu_request    = var.cpu_request
  cpu_limit      = var.cpu_limit

  # Environment Variables
  environment_variables = merge(
    {
      NODE_ENV = var.environment
      PORT     = tostring(var.container_port)
    },
    var.additional_environment_variables
  )

  # IAM Configuration (for IRSA - IAM Roles for Service Accounts)
  # Note: You'll need to create an IAM role separately if you need AWS service access
  iam_role_arn = var.iam_role_arn

  # Service Configuration
  enable_session_affinity = var.enable_session_affinity

  # Ingress Configuration
  enable_ingress                 = var.enable_ingress
  alb_scheme                     = var.alb_scheme
  enable_https                   = var.enable_https
  acm_certificate_arn            = var.enable_https ? data.terraform_remote_state.acm.outputs.certificate_arn : ""
  additional_ingress_annotations = var.additional_ingress_annotations

  # Autoscaling Configuration
  enable_autoscaling        = var.enable_autoscaling
  min_replicas              = var.min_replicas
  max_replicas              = var.max_replicas
  cpu_target_utilization    = var.cpu_target_utilization
  memory_target_utilization = var.memory_target_utilization
}
