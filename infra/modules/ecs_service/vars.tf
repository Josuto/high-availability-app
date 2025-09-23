variable "aws_region" {
  description = "AWS region"
  default     = "eu-west-1" 
}

variable "project_name" {
  description = "The name of the project this module belongs to"
  type        = string
}

variable "container_name" {
  description = "Name of the app container to be deployed"
  default     = "my-app"
}

variable "container_port" {
  description = "Port the app container is available from"
  default     = 3000 
}

variable "ecr_app_image" {
  description = "App ECR Image. Specified at the infra creation/destruction pipelines"
  type        = string
}

variable "task_role_arn" {
  description = "Specifies the ARN of an IAM role that the ECS tasks will assume"
  default     = ""
}

variable "ecs_cluster_arn" {
  description = "ECS cluster ARN"
  type        = string 
}

variable "ecs_task_desired_count" {
  description = "The number of tasks that you want to run for this service"
  type        = number
}

variable "deployment_minimum_healthy_percent" {
  description = "Lower limit of healthy tasks that must be running during deployment so that the service remains available"
  default     = 100
}

variable "deployment_maximum_percent" {
  description = "Upper limit of health tasks that must be running during deployment"
  default     = 200
}

variable "alb_target_group_id" {
  description = "The target group to link the ECS service to"
  type        = string
}

variable "log_group" {
  description = "AWS Cloudwatch log group"
  default     = "my-app-lg"
}