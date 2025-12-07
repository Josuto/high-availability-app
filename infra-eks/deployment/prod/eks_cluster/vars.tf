variable "state_bucket_name" {
  description = "The name of the S3 bucket specifying the Terraform state"
  type        = string
}

variable "project_name" {
  description = "The name of the project"
  type        = string
}

variable "environment" {
  description = "The deployment environment (dev or prod)"
  type        = string
  default     = "prod"
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "The environment must be either 'dev' or 'prod'."
  }
}

variable "kubernetes_version" {
  description = "Kubernetes version to use for the EKS cluster"
  type        = string
  default     = "1.28"
}

variable "endpoint_public_access" {
  description = "Enable public API server endpoint access per environment"
  type        = map(bool)
  default = {
    dev  = true
    prod = false # Prod uses private endpoint for security
  }
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days per environment"
  type        = map(number)
  default = {
    dev  = 7
    prod = 30
  }
}

variable "kms_key_arn" {
  description = "ARN of KMS key for encrypting Kubernetes secrets (optional)"
  type        = string
  default     = ""
}
