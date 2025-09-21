module "ecr" {
  source              = "../../modules/ecr"
  ecr_repository_name = "demo-ecr-repository"
}