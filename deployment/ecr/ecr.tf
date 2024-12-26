# Create an ECR repository for the dummy-app
resource "aws_ecr_repository" "dummy-app-ecr-repository" {
  name = "dummy-app-ecr-repository"

  lifecycle {
    ignore_changes = [
      # Add any attributes you don't want to trigger recreation
      name,
    ]
  }
}

# Output the ECR repository URL to consume in the GitHub Actions pipeline
output "dummy-app-ecr-repository-url" {
  value = aws_ecr_repository.dummy-app-ecr-repository.repository_url
}