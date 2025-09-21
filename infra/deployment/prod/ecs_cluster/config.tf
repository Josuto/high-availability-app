data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket = "josumartinez-terraform-state-bucket"
    key    = "deployment/prod/vpc/terraform.tfstate"
    # region = "eu-west-1" # When omitted, that of the provider is taken
  }
}

module "ecs_cluster" {
  source              = "../../../modules/ecs_cluster"
  cluster_name        = "demo-ecs-cluster"
  vpc_id              = data.terraform_remote_state.vpc.outputs.vpc_id
  vpc_private_subnets = data.terraform_remote_state.vpc.outputs.private_subnets
}