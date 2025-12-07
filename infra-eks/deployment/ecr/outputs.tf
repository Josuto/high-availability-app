output "ecr_repository_url" {
  description = "ECR repository URL required by the deployment/destruction pipelines"
  value       = module.ecr.ecr_repository_url
}

output "ecr_repository_name" {
  description = "ECR repository name required by the deployment/destruction pipelines"
  value       = module.ecr.ecr_repository_name
}

output "ecr_repository_arn" {
  description = "ECR repository ARN"
  value       = module.ecr.ecr_repository_arn
}
