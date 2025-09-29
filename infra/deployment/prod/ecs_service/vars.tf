variable "aws_region" {
  description = "AWS Region"
  default     = "eu-west-1"
}

variable "project_name" {
  description = "The name of the project this module belongs to"
  type        = string
}

variable "ecr_app_image" {
  description = "App ECR image"
  type        = string
}

variable "ecs_task_desired_count" {
  description = "The number of tasks that you want to run for this service"
  default     = 2
}

variable "ecs_task_min_capacity" {
  description = "The min number of tasks running at the ECS cluster"
  default     = 1
}

variable "ecs_task_max_capacity" {
  description = "The max number of tasks running at the ECS cluster"
  default     = 2
}

variable "target_performance_goal" {
  description = "Amount of requests per minute that a container can handle without seeing performance degradation"
  default     = 100
}
