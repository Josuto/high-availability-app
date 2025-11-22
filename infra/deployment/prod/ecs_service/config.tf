data "terraform_remote_state" "ecr" {
  backend = "s3"
  config = {
    bucket = var.state_bucket_name
    key    = "deployment/ecr/terraform.tfstate"
    # region = "eu-west-1" # When omitted, that of the provider is taken
  }
}

data "terraform_remote_state" "ecs_cluster" {
  backend = "s3"
  config = {
    bucket = var.state_bucket_name
    key    = "deployment/prod/ecs_cluster/terraform.tfstate"
    # region = "eu-west-1" # When omitted, that of the provider is taken
  }
}

data "terraform_remote_state" "alb" {
  backend = "s3"
  config = {
    bucket = var.state_bucket_name
    key    = "deployment/prod/alb/terraform.tfstate"
    # region = "eu-west-1" # When omitted, that of the provider is taken
  }
}

data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket = var.state_bucket_name
    key    = "deployment/prod/vpc/terraform.tfstate"
    # region = "eu-west-1" # When omitted, that of the provider is taken
  }
}

module "ecs_service" {
  source                     = "../../../modules/ecs_service"
  aws_region                 = var.aws_region
  project_name               = var.project_name
  environment                = var.environment
  container_name             = "${var.environment}-${var.project_name}"
  log_group                  = "${var.environment}-${var.project_name}-lg"
  ecr_app_image              = var.ecr_app_image
  ecs_task_desired_count     = var.ecs_task_desired_count
  ecs_cluster_arn            = data.terraform_remote_state.ecs_cluster.outputs.ecs_cluster_arn
  ecs_capacity_provider_name = data.terraform_remote_state.ecs_cluster.outputs.ecs_capacity_provider_name
  alb_target_group_id        = data.terraform_remote_state.alb.outputs.alb_target_group_id
  alb_security_group_id      = data.terraform_remote_state.alb.outputs.alb_security_group_id
  vpc_id                     = data.terraform_remote_state.vpc.outputs.vpc_id
  vpc_private_subnets        = data.terraform_remote_state.vpc.outputs.private_subnets
}