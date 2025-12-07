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

  validation {
    condition = alltrue([
      for count in values(var.image_retention_max_count) : count > 0 && count <= 1000
    ])
    error_message = "Image retention max count must be between 1 and 1000 for each environment."
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
