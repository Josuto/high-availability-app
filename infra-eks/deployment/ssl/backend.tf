terraform {
  backend "s3" {
    bucket = "YOUR_TERRAFORM_STATE_BUCKET_NAME"
    key    = "deployment/ssl/terraform.tfstate"
  }
}
