# Output the ECR repository URL to consume in the GitHub Actions pipeline
output "app-ecr-repository-url" {
  value = aws_ecr_repository.app-ecr-repository.repository_url
}