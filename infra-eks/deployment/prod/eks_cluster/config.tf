# Fetch VPC data from the EKS VPC deployment
data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket = var.state_bucket_name
    key    = "deployment/prod/vpc/terraform.tfstate"
    # region = "eu-west-1" # When omitted, region of the provider is used
  }
}

# EKS Cluster Module
module "eks_cluster" {
  source = "../../../modules/eks_cluster"

  project_name        = var.project_name
  environment         = var.environment
  vpc_id              = data.terraform_remote_state.vpc.outputs.vpc_id
  vpc_private_subnets = data.terraform_remote_state.vpc.outputs.vpc_private_subnets
  vpc_public_subnets  = data.terraform_remote_state.vpc.outputs.vpc_public_subnets

  kubernetes_version     = var.kubernetes_version
  endpoint_public_access = var.endpoint_public_access
  log_retention_days     = var.log_retention_days
  kms_key_arn            = var.kms_key_arn

  # Note: ALB security group not needed here as ALB is created by Ingress
  alb_security_group_id = ""
}
