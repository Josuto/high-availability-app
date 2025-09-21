# Output the ECR repository URL to consume in the GitHub Actions pipeline
output "ecr_repository_url" {
  value = aws_ecr_repository.app-ecr-repository.repository_url
}
