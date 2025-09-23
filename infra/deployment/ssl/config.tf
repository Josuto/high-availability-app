data "terraform_remote_state" "hosted_zone" {
  backend = "s3"
  config = {
    bucket = "josumartinez-terraform-state-bucket"
    key    = "deployment/hosted_zone/terraform.tfstate"
    # region = "eu-west-1" # When omitted, that of the provider is taken
  }
}

module "ssl" {
  source                   = "../../modules/ssl" 
  project_name             = "high-availability-app"
  root_domain_name         = "josumartinez.com"
  subject_alternative_name = "*.josumartinez.com"
  hosted_zone_id           = data.terraform_remote_state.hosted_zone.outputs.hosted_zone_id
}