terraform {
  backend "s3" {
    key     = "deployment/app/eks_cluster/terraform.tfstate"
    encrypt = true
  }
}
