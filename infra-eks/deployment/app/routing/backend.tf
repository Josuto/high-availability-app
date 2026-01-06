terraform {
  backend "s3" {
    key     = "deployment/app/routing/terraform.tfstate"
    encrypt = true
  }
}
