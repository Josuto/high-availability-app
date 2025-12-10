variable "project_name" {
  description = "The name of the project this module belongs to"
  type        = string
}

variable "environment" {
  description = "The environment to deploy to (dev or prod)"
  type        = string
  default     = "prod"

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "The environment must be one of: dev, prod."
  }
}

variable "state_bucket_name" {
  description = "S3 bucket name for Terraform remote state"
  type        = string
}

variable "helm_chart_version" {
  description = "Version of the AWS Load Balancer Controller Helm chart"
  type        = string
  default     = "1.6.0"
}
