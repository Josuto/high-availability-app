variable "project_name" {
  description = "The name of the project this module belongs to"
  type        = string
}

variable "root_domain_name" {
  description = "The app root domain name"
  type        = string
}

variable "force_destroy" {
  description = "Enable the destruction of the hosted zone"
  type        = map(bool)
  default = {
    "dev"  = true
    "prod" = false
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
