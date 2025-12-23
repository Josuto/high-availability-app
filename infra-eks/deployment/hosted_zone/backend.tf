terraform {
  backend "s3" {
    key     = "deployment/hosted_zone/terraform.tfstate"
    encrypt = true
  }
}
