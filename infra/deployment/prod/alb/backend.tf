terraform {
  # Specify the minimum Terraform version required to run this configuration.
  # This ensures consistent behavior across different environments and prevents
  # compatibility issues from older or newer versions that might interpret code differently.
  required_version = ">= 1.5.0"

  # Define the required providers and their version constraints.
  # Pinning provider versions ensures reproducible deployments and prevents
  # breaking changes from newer provider releases from affecting existing infrastructure.
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"  # Allow version 5.0 and above
    }
  }

  backend "s3" {
    key     = "deployment/prod/alb/terraform.tfstate"
    encrypt = true
  }
}