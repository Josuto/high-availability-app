variable "project_name" {
  description = "The name of the project this module belongs to"
  type        = string
}

variable "ecs_max_utilisation" {
  description = "Max utilisation of the ECS cluster percentage-wise. The ECS calculates its current utilisation by masuring the total CPU/memory capacity reserved by the running tasks against the total available capacity of all EC2 instances of the cluster"
  type        = map(number)
  default = {
    "dev"  = 100
    "prod" = 75
  }
}

variable "managed_termination_protection_setting" {
  description = "When enabled, prevents the ASG from terminating an instance that is currently running one or more tasks"
  type        = map(string)
  default = {
    "dev"  = "DISABLED" # Must be DISABLED when ASG protect_from_scale_in is false
    "prod" = "ENABLED"  # Can be ENABLED when ASG protect_from_scale_in is true
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

variable "state_bucket_name" {
  description = "The name of the S3 bucket specifiying the Terraform state"
  type        = string
}
