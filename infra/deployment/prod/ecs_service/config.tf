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
  source                     = "../../../modules/ecs_service"
  container_name             = "demo-app"
  aws_region                 = var.aws_region
  project_name               = var.project_name
  ecr_app_image              = var.ecr_app_image
  ecs_task_desired_count     = var.ecs_task_desired_count
  environment                = var.environment
  ecs_cluster_arn            = data.terraform_remote_state.ecs_cluster.outputs.ecs_cluster_arn
  ecs_capacity_provider_name = data.terraform_remote_state.ecs_cluster.outputs.ecs_capacity_provider_name
  alb_target_group_id        = data.terraform_remote_state.alb.outputs.alb_target_group_id
}