terraform {
  backend "s3" {
    bucket = "YOUR_TERRAFORM_STATE_BUCKET_NAME" # Replace with your S3 bucket name
    key    = "deployment/prod/aws_lb_controller/terraform.tfstate"
    # region = "eu-west-1"  # When omitted, region of the provider is used
  }
}
