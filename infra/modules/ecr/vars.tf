variable "project_name" {
  description = "The name of the project this module belongs to"
  type        = string
}

variable "image_retention_max_count" {
  description = "Maximum number of tagged images to retain per environment."
  type        = map(number)
  default = {
    "dev"  = 3
    "prod" = 10
  }
}

variable "environment" {
  description = "The environment to deploy to (dev or prod)."
  type        = string
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "The environment must be either 'dev' or 'prod'."
  }
}