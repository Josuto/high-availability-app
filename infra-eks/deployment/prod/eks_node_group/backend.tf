terraform {
  backend "s3" {
    key     = "deployment/prod/eks_node_group/terraform.tfstate"
    encrypt = true
  }
}
