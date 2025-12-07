terraform {
  backend "s3" {
    bucket = "YOUR_STATE_BUCKET_NAME" # Replace with your S3 bucket name
    key    = "deployment/prod/eks_node_group/terraform.tfstate"
    # region = "eu-west-1"  # When omitted, region of the provider is used
  }
}
