terraform {
  backend "s3" {
    key     = "deployment/prod/vpc/terraform.tfstate"
    encrypt = true
  }
}
