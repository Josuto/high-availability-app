data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket = "josumartinez-terraform-state"
    key    = "deployment/prod/vpc/terraform.tfstate"
    # region = "eu-west-1" # When omitted, that of the provider is taken
  }
}

data "terraform_remote_state" "ecs_cluster" {
  backend = "s3"
  config = {
    bucket = "josumartinez-terraform-state"
    key    = "deployment/prod/ecs_cluster/terraform.tfstate"
    # region = "eu-west-1" # When omitted, that of the provider is taken
  }
}

data "terraform_remote_state" "ssl" {
  backend = "s3"
  config = {
    bucket = "josumartinez-terraform-state"
    key    = "deployment/ssl/terraform.tfstate"
    # region = "eu-west-1" # When omitted, that of the provider is taken
  }
}

module "alb" {
  source                         = "../../../modules/alb"
  vpc_id                         = data.terraform_remote_state.vpc.outputs.vpc_id
  vpc_public_subnets             = data.terraform_remote_state.vpc.outputs.public_subnets
  ecs_security_group_id          = data.terraform_remote_state.ecs_cluster.outputs.ecs_security_group_id
  acm_certificate_validation_arn = data.terraform_remote_state.ssl.outputs.acm_certificate_validation_arn
}