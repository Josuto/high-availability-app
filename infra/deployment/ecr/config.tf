module "ecr" {
  source              = "../../modules/ecr"
  ecr_repository_name = "${var.environment}-${var.project_name}-ecr-repository"
  project_name        = var.project_name
  environment         = var.environment 
}