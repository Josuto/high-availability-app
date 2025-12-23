terraform {
  backend "s3" {
    key     = "deployment/prod/k8s_app/terraform.tfstate"
    encrypt = true
  }
}
