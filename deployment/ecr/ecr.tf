# Create an ECR repository for the dummy-app
resource "aws_ecr_repository" "my-ecr-repository" {
  name = "dummy-app-ecr-repository"
}

import {
  to = aws_ecr_repository.my-ecr-repository
  id = "dummy-app-ecr-repository"
}

# Output the ECR repository URL to consume in the GitHub Actions pipeline
output "dummy-app-ecr-repository-url" {
  value = aws_ecr_repository.my-ecr-repository.repository_url
}