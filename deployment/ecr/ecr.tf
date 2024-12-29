# Create an ECR repository for the dummy-app
resource "aws_ecr_repository" "my-ecr-repository" {
  name = "dummy-app-ecr-repository"
}

# ECR policy to retain only the most recent image
resource "aws_ecr_lifecycle_policy" "my_ecr_policy" {
  repository = aws_ecr_repository.my-ecr-repository.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Retain only the most recent image"
        selection = {
          tagStatus    = "any"
          countType    = "imageCountMoreThan"
          countNumber  = 1
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# Output the ECR repository URL to consume in the GitHub Actions pipeline
output "dummy-app-ecr-repository-url" {
  value = aws_ecr_repository.my-ecr-repository.repository_url
}