output "ecr_repository_url" {
  description = "ECR repository URL required by the deployment/destruction GHA pipelines"
  value       = module.ecr.ecr_repository_url
}

output "ecr_repository_name" {
  description = "ECR repository name required by the deployment/destruction GHA pipelines"
  value       = module.ecr.ecr_repository_name
}
