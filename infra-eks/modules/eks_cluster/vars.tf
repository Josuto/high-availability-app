variable "project_name" {
  description = "The name of the project"
  type        = string
}

variable "environment" {
  description = "The deployment environment (dev or prod)"
  type        = string
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "The environment must be either 'dev' or 'prod'."
  }
}

variable "vpc_id" {
  description = "VPC ID where the EKS cluster will be created"
  type        = string
}

variable "vpc_private_subnets" {
  description = "List of private subnet IDs for the EKS cluster"
  type        = list(string)
}

variable "vpc_public_subnets" {
  description = "List of public subnet IDs for the EKS cluster"
  type        = list(string)
}

variable "kubernetes_version" {
  description = "Kubernetes version to use for the EKS cluster"
  type        = string
  default     = "1.32"
}

variable "endpoint_public_access" {
  description = "Enable public API server endpoint access per environment"
  type        = map(bool)
  default = {
    dev  = true
    prod = false
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

variable "alb_security_group_id" {
  description = "Security group ID of the ALB (optional, for allowing traffic to pods)"
  type        = string
  default     = ""
}
