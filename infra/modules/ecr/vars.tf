variable "project_name" {
  description = "The name of the project this module belongs to"
  type        = string
}

variable "ecr_repository_name" {
  description = "Name of the ECR repository that hosts the app image"
  default     = "my-ecr-repository"
}