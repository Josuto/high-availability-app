variable "project_name" {
  description = "The name of the project this module belongs to"
  type        = string
}

variable "ecs_instance_type" {
  description = "Type of the AWS EC2 instances to be deployed at ECS"
  type        = string
  default     = "t2.micro"
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
}

variable "instance_max_size" {
  description = "The maximum number of EC2 instances the ASG is allowed to launch"
  type        = number
  default     = 2
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
