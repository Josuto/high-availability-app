module "hosted_zone" {
  source           = "../../modules/hosted_zone"
  project_name     = "high-availability-app"
  root_domain_name = "josumartinez.com."
  force_destroy    = true
}