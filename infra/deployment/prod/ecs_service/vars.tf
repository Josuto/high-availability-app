variable "aws_region" {
  description = "AWS Region"
  default     = "eu-west-1"
}

variable "ecr_app_image" {
  description = "App ECR image"
  type        = string
}
