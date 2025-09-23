module "ecr" {
  source              = "../../modules/ecr"
  project_name        = "high-availability-app"
  ecr_repository_name = "demo-ecr-repository"
}