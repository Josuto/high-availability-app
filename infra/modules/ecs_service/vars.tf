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
        field = "cpu" # Spread by least available CPU (Cost Optimization)
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
  default     = "dev"
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "The environment must be either 'dev' or 'prod'."
  }
}