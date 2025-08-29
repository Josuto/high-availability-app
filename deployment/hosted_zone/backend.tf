terraform {
  backend "s3" {
    bucket = "dummy-app-terraform-state-bucket" # Must be unique in case of making the bucket public
    key    = "deployment/states/hosted_zone/terraform.tfstate"
    region = "eu-west-1"
  }
}