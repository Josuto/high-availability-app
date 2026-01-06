#####################################
# Terraform and Provider Configuration
#####################################

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

#####################################
# AWS Provider with Default Tags
#####################################

provider "aws" {
  # Region can be set via AWS_REGION environment variable or AWS config

  # Default tags applied to all resources
  # These tags are inherited by all resources created by this configuration
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
