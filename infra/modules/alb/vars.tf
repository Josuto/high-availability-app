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
  default     = 3000 
}

variable "deregistration_delay" {
  description = "The amount seconds for the ALB to wait before completing the deregistration of a target"
  default     = 30
}

variable "health_check_path" {
  description = "The path to the app health check endpoint"
  default     = "/health"
}

variable "healthcheck_matcher" {
  description = "The expected HTTP response code or codes for a successful health check"
  default     = "200"
}

variable "acm_certificate_validation_arn" {
  description = "The ARN of the ACM certificate attached to the ALB"
  type        = string
}

variable "enable_deletion_protection" {
  description = "Values for the ALB's enable_deletion_protection variable based on the running environment"
  default = {
    "dev"  = false
    "prod" = true
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