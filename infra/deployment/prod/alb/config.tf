data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket = var.state_bucket_name
    key    = "deployment/prod/vpc/terraform.tfstate"
    # region = "eu-west-1" # When omitted, that of the provider is taken
  }
}

data "terraform_remote_state" "ssl" {
  backend = "s3"
  config = {
    bucket = var.state_bucket_name
    key    = "deployment/ssl/terraform.tfstate"
    # region = "eu-west-1" # When omitted, that of the provider is taken
  }
}

module "alb" {
  source                         = "../../../modules/alb"
  alb_name                       = "demo-alb" 
  project_name                   = var.project_name
  environment                    = var.environment 
  vpc_id                         = data.terraform_remote_state.vpc.outputs.vpc_id
  vpc_public_subnets             = data.terraform_remote_state.vpc.outputs.public_subnets
  acm_certificate_validation_arn = data.terraform_remote_state.ssl.outputs.acm_certificate_validation_arn
}