terraform {
  backend "s3" {
    key     = "deployment/ssl/terraform.tfstate"
    encrypt = true
  }
}
