data "terraform_remote_state" "alb" {
  backend = "s3"
  config = {
    bucket = "josumartinez-terraform-state"
    key    = "deployment/prod/alb/terraform.tfstate"
    # region = "eu-west-1" # When omitted, that of the provider is taken
  }
}

data "terraform_remote_state" "hosted_zone" {
  backend = "s3"
  config = {
    bucket = "josumartinez-terraform-state"
    key    = "deployment/hosted_zone/terraform.tfstate"
    # region = "eu-west-1" # When omitted, that of the provider is taken
  }
}

module "routing" {
  source             = "../../../modules/routing"
  root_domain_name   = "josumartinez.com"
  www_domain_name    = "www.josumartinez.com"
  alb_dns_name       = data.terraform_remote_state.alb.outputs.alb_dns_name
  alb_hosted_zone_id = data.terraform_remote_state.alb.outputs.alb_hosted_zone_id
  hosted_zone_id     = data.terraform_remote_state.hosted_zone.outputs.hosted_zone_id
}