module "hosted_zone" {
  source           = "../../modules/hosted_zone"
  root_domain_name = "josumartinez.com."
  force_destroy    = true
}