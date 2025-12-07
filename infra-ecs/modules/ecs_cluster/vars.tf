variable "project_name" {
  description = "The name of the project this module belongs to"
  type        = string
}

variable "ecs_instance_type" {
  description = "Type of the AWS EC2 instances to be deployed at ECS"
  type        = string
  default     = "t2.micro"

  validation {
    condition     = can(regex("^[a-z][1-9][0-9]*[a-z]*\\.(nano|micro|small|medium|large|[0-9]*xlarge)$", var.ecs_instance_type))
    error_message = "Instance type must be a valid EC2 instance type format (e.g., t2.micro, t3.small, m5.large)."
  }
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "vpc_private_subnets" {
  description = "The list of existing VPC private subnets"
  type        = list(string)
}

variable "instance_min_size" {
  description = "The minimum number of EC2 instances the ASG must maintain"
  type        = number
  default     = 1

  validation {
    condition     = var.instance_min_size >= 0 && var.instance_min_size <= 1000
    error_message = "Instance min size must be between 0 and 1000."
  }
}

variable "instance_max_size" {
  description = "The maximum number of EC2 instances the ASG is allowed to launch"
  type        = number
  default     = 2

  validation {
    condition     = var.instance_max_size >= 1 && var.instance_max_size <= 1000
    error_message = "Instance max size must be between 1 and 1000."
  }

  validation {
    condition     = var.instance_max_size >= var.instance_min_size
    error_message = "Instance max size must be greater than or equal to instance min size."
  }
}

variable "protect_from_scale_in" {
  description = "It true, the ASG will not terminate any scale-in protected EC2 instance"
  type        = map(bool)
  default = {
    "dev"  = false
    "prod" = true
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
