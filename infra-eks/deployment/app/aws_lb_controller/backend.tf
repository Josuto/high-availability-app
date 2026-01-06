terraform {
  backend "s3" {
    key     = "deployment/app/aws_lb_controller/terraform.tfstate"
    encrypt = true
  }
}
