# 
data "aws_ecr_repository" "existing_repo" {
  name = "dummy-app-ecr-repository"
}

# Create an ECR repository for the dummy-app
resource "aws_ecr_repository" "dummy-app-ecr-repository" {
  count = length(data.aws_ecr_repository.existing_repo.id) == 0 ? 1 : 0
  name = "dummy-app-ecr-repository"
}

# Output the ECR repository URL to consume in the GitHub Actions pipeline
output "dummy-app-ecr-repository-url" {
  value = aws_ecr_repository.dummy-app-ecr-repository.repository_url
}