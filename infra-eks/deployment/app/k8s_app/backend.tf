terraform {
  backend "s3" {
    key     = "deployment/app/k8s_app/terraform.tfstate"
    encrypt = true
  }
}
