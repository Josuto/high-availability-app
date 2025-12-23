terraform {
  backend "s3" {
    key     = "deployment/ecr/terraform.tfstate"
    encrypt = true
  }
}
