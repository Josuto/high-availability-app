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
      version = "~> 5.0"  # Allow minor and patch updates within major version 5
    }
  }

  backend "s3" {
    bucket         = "josumartinez-terraform-state-bucket" # Must be unique in case of making the bucket public
    key            = "deployment/prod/alb/terraform.tfstate"
    encrypt        = true # Security best practice
    # dynamodb_table = "josumartinez-terraform-locks" # To prevent state corruption due to simultaneous state update. The DynamoDB table must be created beforehand
  }
}