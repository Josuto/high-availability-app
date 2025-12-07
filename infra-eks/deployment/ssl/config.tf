data "terraform_remote_state" "hosted_zone" {
  backend = "s3"
  config = {
    bucket = var.state_bucket_name
    key    = "deployment/hosted_zone/terraform.tfstate"
  }
}

module "ssl" {
  source                   = "../../modules/ssl"
  root_domain_name         = var.root_domain
  subject_alternative_name = "*.${var.root_domain}"
  project_name             = var.project_name
  environment              = var.environment
  hosted_zone_id           = data.terraform_remote_state.hosted_zone.outputs.hosted_zone_id
}
