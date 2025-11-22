module "hosted_zone" {
  source           = "../../modules/hosted_zone"
  root_domain_name = "${var.root_domain}."
  project_name     = var.project_name
  environment      = var.environment
}