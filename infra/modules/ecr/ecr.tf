# Create the app ECR repository
resource "aws_ecr_repository" "app-ecr-repository" {
  name = var.ecr_repository_name

  tags = {
    Project = var.project_name
  }
}

# ECR policy to retain only the most recent app image
resource "aws_ecr_lifecycle_policy" "ecr_policy" {
  repository = aws_ecr_repository.app-ecr-repository.name

  policy = jsonencode({
    rules = [
      {
        "rulePriority" : 1,
        "description" : "Expire all untagged images, keeping the one newest untagged image.",
        "selection" : {
          "tagStatus" : "untagged",
          "countType" : "imageCountMoreThan",
          "countNumber" : 1 // Keep 1 untagged image, delete the rest
        },
        "action" : {
          "type" : "expire"
        }
      },
      # Note: This rule targets ALL tagged images and enforces the count.
      # You could add more explicit rules here for 'dev-' and 'prod-' prefixes if needed.
      {
        "rulePriority" : 2,
        "description" : "Retain max tagged images based on the environment setting.",
        "selection" : {
          "tagStatus" : "tagged",
          "countType" : "imageCountMoreThan",
          "countNumber" : lookup(var.image_retention_max_count, var.environment)
        },
        "action" : {
          "type" : "expire"
        }
      }
    ]
  })
}
