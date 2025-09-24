module "ecr" {
  source              = "../../modules/ecr"
  ecr_repository_name = "demo-ecr-repository"
  project_name        = var.project_name
}