terraform {
  backend "s3" {
    bucket = "dummy-app-terraform-state-bucket" # Must be unique in case of making the bucket public
    key    = "deployment/states/ecs/terraform.tfstate"
    region = "eu-west-1"
  }
}