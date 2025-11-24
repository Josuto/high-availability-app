data "terraform_remote_state" "alb" {
  backend = "s3"
  config = {
    bucket = var.state_bucket_name
    key    = "deployment/prod/alb/terraform.tfstate"
    # region = "eu-west-1" # When omitted, that of the provider is taken
  }
}

data "terraform_remote_state" "hosted_zone" {
  backend = "s3"
  config = {
    bucket = var.state_bucket_name
    key    = "deployment/hosted_zone/terraform.tfstate"
    # region = "eu-west-1" # When omitted, that of the provider is taken
  }
}

module "routing" {
  source             = "../../../modules/routing"
  root_domain_name   = var.root_domain
  www_domain_name    = "www.${var.root_domain}"
  alb_dns_name       = data.terraform_remote_state.alb.outputs.alb_dns_name
  alb_hosted_zone_id = data.terraform_remote_state.alb.outputs.alb_hosted_zone_id
  hosted_zone_id     = data.terraform_remote_state.hosted_zone.outputs.hosted_zone_id
}
