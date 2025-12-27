data "terraform_remote_state" "hosted_zone" {
  backend = "s3"
  config = {
    bucket = var.state_bucket_name
    key    = "deployment/hosted_zone/terraform.tfstate"
    # region = "eu-west-1" # When omitted, that of the provider is taken
  }
}

data "terraform_remote_state" "k8s_app" {
  backend = "s3"
  config = {
    bucket = var.state_bucket_name
    key    = "deployment/prod/k8s_app/terraform.tfstate"
    # region = "eu-west-1"  # When omitted, region of the provider is used
  }
}


module "routing" {
  source           = "../../../modules/routing"
  root_domain_name = var.root_domain
  ingress_hostname = data.terraform_remote_state.k8s_app.outputs.ingress_hostname
  alb_zone_id      = data.terraform_remote_state.k8s_app.outputs.alb_zone_id
  hosted_zone_id   = data.terraform_remote_state.hosted_zone.outputs.hosted_zone_id
}
