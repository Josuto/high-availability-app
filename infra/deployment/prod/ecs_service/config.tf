data "terraform_remote_state" "ecr" {
  backend = "s3"
  config = {
    bucket = "josumartinez-terraform-state-bucket"
    key    = "deployment/ecr/terraform.tfstate"
    # region = "eu-west-1" # When omitted, that of the provider is taken
  }
}

data "terraform_remote_state" "ecs_cluster" {
  backend = "s3"
  config = {
    bucket = "josumartinez-terraform-state-bucket"
    key    = "deployment/prod/ecs_cluster/terraform.tfstate"
    # region = "eu-west-1" # When omitted, that of the provider is taken
  }
}

data "terraform_remote_state" "alb" {
  backend = "s3"
  config = {
    bucket = "josumartinez-terraform-state-bucket"
    key    = "deployment/prod/alb/terraform.tfstate"
    # region = "eu-west-1" # When omitted, that of the provider is taken
  }
}

module "ecs_service" {
  source              = "../../../modules/ecs_service"
  aws_region          = var.AWS_REGION
  ecr_app_image       = data.terraform_remote_state.ecr.outputs.app-ecr-repository-url
  ecs_cluster_arn     = data.terraform_remote_state.ecs_cluster.outputs.ecs_cluster_arn
  alb_target_group_id = data.terraform_remote_state.alb.outputs.alb_target_group_id
}