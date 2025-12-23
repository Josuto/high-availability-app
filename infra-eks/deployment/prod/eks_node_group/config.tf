#####################################
# Data Sources - Remote State
#####################################

# Reference the VPC remote state
data "terraform_remote_state" "vpc" {
  backend = "s3"

  config = {
    bucket = var.state_bucket_name
    key    = "deployment/prod/vpc/terraform.tfstate"
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

#####################################
# EKS Node Group Module
#####################################

module "eks_node_group" {
  source = "../../../modules/eks_node_group"

  # Project Configuration
  project_name = var.project_name
  environment  = var.environment

  # EKS Cluster Configuration
  eks_cluster_name = data.terraform_remote_state.eks_cluster.outputs.cluster_id

  # VPC Configuration
  vpc_private_subnets = data.terraform_remote_state.vpc.outputs.vpc_private_subnets

  # Node Group Configuration
  instance_type = var.instance_type[var.environment]
  desired_size  = var.desired_size
  max_size      = var.max_size
  min_size      = var.min_size
  capacity_type = var.capacity_type
  disk_size     = var.disk_size[var.environment]
}
