variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "eu-west-1"
}

variable "project_name" {
  description = "The name of the project this module belongs to"
  type        = string
}

variable "single_nat_gateway" {
  description = "Values for the single_nat_gateway variable based on the running environment"
  type        = map(bool)
  default = {
    "dev"  = true  # Single NAT Gateway for dev (cost savings)
    "prod" = false # Multiple NAT Gateways for prod (high availability)
  }
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
