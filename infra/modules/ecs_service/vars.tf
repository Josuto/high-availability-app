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

variable "cpu_limit" {
  description = "The limit of usage of CPU on a task/container"
  default     = 256
}

variable "memory_limit" {
  description = "The limit of usage of memory on a task/container"
  default     = 128
}

variable "ecr_app_image" {
  description = "App ECR Image. Specified at the infra creation/destruction pipelines"
  type        = string
}

variable "task_role_arn" {
  description = "Specifies the ARN of an IAM role that the app will assume"
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

variable "alb_security_group_id" {
  description = "The ID of the ALB's security group"
  type        = string
}

variable "ecs_capacity_provider_name" {
  description = "The name of the ECS Capacity Provider that enables app auto-scaling"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "vpc_private_subnets" {
  description = "The list of existing VPC private subnets"
  type        = list(string) 
}

variable "log_group" {
  description = "AWS Cloudwatch log group"
  default     = "my-app-lg"
}

variable "ordered_placement_strategy_type" {
  description = "Strategy that defines how to place tasks on the ECS cluster EC2 instances"
  default = {
    "dev"  = "binpack" # pack tasks onto as few instances as possible (saves cost)
    "prod" = "spread" # spread by AZ, instance, or any attribute
  }
}

variable "ordered_placement_strategy_field" {
  description = "Strategy that defines how to place tasks on the ECS cluster EC2 instances"
  default = {
    "dev"  = "cpu" # place new tasks on the instance with the least available CPU that can still run the task
    "prod" = "attribute:ecs.availability-zone" # spread by AZ
  }
}

variable "environment" {
  description = "The environment to deploy to (dev or prod)."
  default     = "dev"
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "The environment must be either 'dev' or 'prod'."
  }
}