variable "project_name" {
  description = "The name of the project this module belongs to"
  type        = string
}

variable "ecs_max_utilisation" {
  description = "Max utilisation of the ECS cluster percentage-wise. The ECS calculates its current utilisation by masuring the total CPU/memory capacity reserved by the running tasks against the total available capacity of all EC2 instances of the cluster"
  default = {
    "dev"  = 100
    "prod" = 75
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