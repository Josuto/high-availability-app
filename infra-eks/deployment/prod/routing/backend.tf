terraform {
  backend "s3" {
    key     = "deployment/prod/routing/terraform.tfstate"
    encrypt = true
  }
}
