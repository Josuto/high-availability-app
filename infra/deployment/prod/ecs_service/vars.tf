variable "aws_region" {
  description = "AWS Region"
  default     = "eu-west-1"
}

variable "ecr_app_image" {
  description = "App ECR image"
  type        = string
}

variable "ecs_task_desired_count" {
  description = "The number of tasks that you want to run for this service"
  default     = 2
}
