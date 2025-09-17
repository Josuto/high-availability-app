# Output the ECR repository URL to consume in the GitHub Actions pipeline
output "app-ecr-repository-url" {
  value = module.ecr.app-ecr-repository-url
}