variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "project_name" {
  description = "The name of the project this module belongs to"
  type        = string
}

variable "container_name" {
  description = "Name of the app container to be deployed"
  type        = string
}

variable "container_port" {
  description = "Port the app container is available from"
  type        = number
  default     = 3000

  validation {
    condition     = var.container_port > 0 && var.container_port <= 65535
    error_message = "Container port must be between 1 and 65535."
  }
}

variable "cpu_limit" {
  description = "The limit of usage of CPU on a task/container"
  type        = number
  default     = 256

  validation {
    condition     = contains([256, 512, 1024, 2048, 4096, 8192, 16384], var.cpu_limit)
    error_message = "CPU limit must be one of: 256, 512, 1024, 2048, 4096, 8192, 16384."
  }
}

variable "memory_limit" {
  description = "The limit of usage of memory on a task/container"
  type        = number
  default     = 128

  validation {
    condition     = var.memory_limit >= 128 && var.memory_limit <= 122880
    error_message = "Memory limit must be between 128 MB and 122880 MB (120 GB)."
  }
}

variable "ecr_app_image" {
  description = "App ECR Image. Specified at the infra creation/destruction pipelines"
  type        = string
}

variable "task_role_arn" {
  description = "Specifies the ARN of an IAM role that the app will assume"
  type        = string
  default     = ""
}

variable "ecs_cluster_arn" {
  description = "ECS cluster ARN"
  type        = string
}

variable "ecs_task_desired_count" {
  description = "The number of tasks that you want to run for this service"
  type        = number

  validation {
    condition     = var.ecs_task_desired_count >= 0
    error_message = "ECS task desired count must be a non-negative integer."
  }
}

variable "deployment_minimum_healthy_percent" {
  description = "Lower limit of healthy tasks that must be running during deployment so that the service remains available"
  type        = number
  default     = 100

  validation {
    condition     = var.deployment_minimum_healthy_percent >= 0 && var.deployment_minimum_healthy_percent <= 100
    error_message = "Deployment minimum healthy percent must be between 0 and 100."
  }
}

variable "deployment_maximum_percent" {
  description = "Upper limit of health tasks that must be running during deployment"
  type        = number
  default     = 200

  validation {
    condition     = var.deployment_maximum_percent >= 100 && var.deployment_maximum_percent <= 200
    error_message = "Deployment maximum percent must be between 100 and 200."
  }
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
  type        = string
}

variable "ordered_placement_strategies" {
  description = "A map of placement strategies (type and field) to apply, keyed by environment (dev/prod)."
  type = map(list(object({
    type  = string
    field = string
  })))
  default = {
    "dev" = [
      {
        type  = "binpack" # Pack tasks onto as few instances as possible (saves cost)
        field = "cpu"     # Spread by least available CPU (Cost Optimization)
      }
    ],
    "prod" = [
      {
        type  = "spread"
        field = "attribute:ecs.availability-zone" # 1st Layer: Spread by AZ (Fault Tolerance)
      },
      {
        type  = "spread"
        field = "attribute:instanceId" # 2nd Layer: Spread by EC2 Instance ID (Single-Instance Failure Protection)
      }
    ]
  }
}

variable "environment" {
  description = "The environment to deploy to (dev or prod)."
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "The environment must be either 'dev' or 'prod'."
  }
}
