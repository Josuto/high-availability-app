# Create the app ECR repository
resource "aws_ecr_repository" "app-ecr-repository" {
  name = "app-ecr-repository"
}

# ECR policy to retain only the most recent app image
resource "aws_ecr_lifecycle_policy" "ecr_policy" {
  repository = aws_ecr_repository.app-ecr-repository.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Retain only the most recent app image"
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
