data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket = var.state_bucket_name
    key    = "deployment/prod/vpc/terraform.tfstate"
    # region = "eu-west-1" # When omitted, that of the provider is taken
  }
}

module "ecs_cluster" {
  source              = "../../../modules/ecs_cluster"
  instance_min_size   = 2
  instance_max_size   = 4
  project_name        = var.project_name
  environment         = var.environment
  vpc_id              = data.terraform_remote_state.vpc.outputs.vpc_id
  vpc_private_subnets = data.terraform_remote_state.vpc.outputs.private_subnets
}
