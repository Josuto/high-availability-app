terraform {
  backend "s3" {
    key     = "deployment/prod/aws_lb_controller/terraform.tfstate"
    encrypt = true
  }
}
