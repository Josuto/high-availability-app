output "ecr_repository_url" {
  description = "The URL of the ECR repository for pushing Docker images"
  value       = aws_ecr_repository.app_ecr_repository.repository_url
}

output "ecr_repository_name" {
  description = "The name of the ECR repository"
  value       = aws_ecr_repository.app_ecr_repository.name
}

output "ecr_repository_arn" {
  description = "The ARN of the ECR repository"
  value       = aws_ecr_repository.app_ecr_repository.arn
}
