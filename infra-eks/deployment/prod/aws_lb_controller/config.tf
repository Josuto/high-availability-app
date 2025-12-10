#####################################
# Data Sources - Remote State
#####################################

# Reference the EKS cluster remote state
data "terraform_remote_state" "eks_cluster" {
  backend = "s3"

  config = {
    bucket = var.state_bucket_name
    key    = "deployment/prod/eks_cluster/terraform.tfstate"
    # region = "eu-west-1"  # When omitted, region of the provider is used
  }
}

# Reference the VPC remote state
data "terraform_remote_state" "vpc" {
  backend = "s3"

  config = {
    bucket = var.state_bucket_name
    key    = "deployment/prod/vpc/terraform.tfstate"
    # region = "eu-west-1"  # When omitted, region of the provider is used
  }
}

#####################################
# AWS Load Balancer Controller Module
#####################################

module "aws_lb_controller" {
  source = "../../../modules/aws_lb_controller"

  # Project Configuration
  project_name = var.project_name
  environment  = var.environment

  # EKS Configuration
  cluster_name            = data.terraform_remote_state.eks_cluster.outputs.cluster_id
  cluster_oidc_issuer_url = data.terraform_remote_state.eks_cluster.outputs.cluster_oidc_issuer_url
  vpc_id                  = data.terraform_remote_state.vpc.outputs.vpc_id

  # Helm Configuration
  helm_chart_version = var.helm_chart_version

  # Tags
  tags = {
    Terraform   = "true"
    Module      = "aws_lb_controller"
    Environment = var.environment
    Project     = var.project_name
  }
}
