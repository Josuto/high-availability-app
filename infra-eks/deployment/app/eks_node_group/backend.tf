terraform {
  backend "s3" {
    key     = "deployment/app/eks_node_group/terraform.tfstate"
    encrypt = true
  }
}
