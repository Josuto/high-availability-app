variable "aws_region" {
  description = "AWS Region"
  default     = "eu-west-1"
}

variable "single_nat_gateway" {
  description = "Values for the single_nat_gateway variable based on the running environment"
  default = {
    "dev"  = true
    "prod" = false
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