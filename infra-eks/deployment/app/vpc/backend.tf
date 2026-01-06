terraform {
  backend "s3" {
    key     = "deployment/app/vpc/terraform.tfstate"
    encrypt = true
  }
}
