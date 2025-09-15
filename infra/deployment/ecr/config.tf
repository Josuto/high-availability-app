module "ecr" {
  source   = "../../modules/ecr"
  app_name = "hello-world"
}