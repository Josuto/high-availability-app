terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  # The region is not hardcoded here. It will be sourced from the AWS_REGION or AWS_DEFAULT_REGION environment variable.

  # Default tags applied to all resources created by this provider
  default_tags {
    tags = {
      ManagedBy   = "Terraform"
      Environment = var.environment
      Project     = var.project_name
      Owner       = "Platform Team"
      CostCenter  = "Engineering"
    }
  }
}
