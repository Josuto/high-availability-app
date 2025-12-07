terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "YOUR_STATE_BUCKET_NAME" # Replace with your S3 bucket name
    key    = "deployment/prod/eks_cluster/terraform.tfstate"
    # region = "eu-west-1"  # When omitted, region of the provider is used
  }
}
