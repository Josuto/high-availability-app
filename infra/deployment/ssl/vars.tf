variable "project_name" {
  description = "The name of the project this module belongs to"
  type        = string
}

variable "state_bucket_name" {
  description = "The name of the S3 bucket specifiying the Terraform state"
  type        = string
}

variable "root_domain" {
  description = "The root domain name for SSL certificate (e.g., example.com)"
  type        = string
}

variable "environment" {
  description = "The environment to deploy to (dev or prod)."
  type        = string
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "The environment must be either 'dev' or 'prod'."
  }
}

