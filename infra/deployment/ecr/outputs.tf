# Output the ECR repository URL to consume in the GitHub Actions pipeline
output "ecr_repository_url" {
  value = module.ecr.ecr_repository_url
}

output "ecr_repository_name" {
  value = module.ecr.ecr_repository_name
}