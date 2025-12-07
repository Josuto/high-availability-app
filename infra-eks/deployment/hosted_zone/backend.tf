terraform {
  backend "s3" {
    bucket = "YOUR_TERRAFORM_STATE_BUCKET_NAME"
    key    = "deployment/hosted_zone/terraform.tfstate"
  }
}
