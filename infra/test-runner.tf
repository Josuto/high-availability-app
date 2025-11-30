# Minimal configuration for running tests
# This file allows terraform test to be executed from the infra directory

terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Mock provider configuration for testing - tests use 'plan' mode
provider "aws" {
  region = "us-east-1"

  # Skip credential validation for plan-only tests
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
}
