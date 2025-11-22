variable "aws_region" {
  description = "AWS Region"
  default     = "eu-west-1"
}

variable "project_name" {
  description = "The name of the project this module belongs to"
  type        = string
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

variable "state_bucket_name" {
  description = "The name of the S3 bucket specifiying the Terraform state"
  type        = string
}