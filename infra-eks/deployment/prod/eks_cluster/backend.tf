terraform {
  backend "s3" {
    key     = "deployment/prod/eks_cluster/terraform.tfstate"
    encrypt = true
  }
}
