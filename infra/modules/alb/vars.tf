variable "project_name" {
  description = "The name of the project this module belongs to"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "vpc_public_subnets" {
  description = "The list of existing VPC public subnets"
  type        = list(string)
}

variable "container_name" {
  description = "Name of the app container to be deployed"
  type        = string
}

variable "container_port" {
  description = "Port the app container is available from"
  type        = number
  default     = 3000

  validation {
    condition     = var.container_port > 0 && var.container_port <= 65535
    error_message = "Container port must be between 1 and 65535."
  }
}

variable "deregistration_delay" {
  description = "The amount seconds for the ALB to wait before completing the deregistration of a target"
  type        = number
  default     = 30

  validation {
    condition     = var.deregistration_delay >= 0 && var.deregistration_delay <= 3600
    error_message = "Deregistration delay must be between 0 and 3600 seconds."
  }
}

variable "health_check_path" {
  description = "The path to the app health check endpoint"
  type        = string
  default     = "/health"
}

variable "healthcheck_matcher" {
  description = "The expected HTTP response code or codes for a successful health check"
  type        = string
  default     = "200"
}

variable "acm_certificate_validation_arn" {
  description = "The ARN of the ACM certificate attached to the ALB"
  type        = string
}

variable "enable_deletion_protection" {
  description = "Values for the ALB's enable_deletion_protection variable based on the running environment"
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
