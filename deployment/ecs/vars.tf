variable "AWS_REGION" {
  description = "AWS Region"
  default     = "eu-west-1"
}

variable "ECS_INSTANCE_TYPE" {
  default = "t2.micro"
}

variable "PATH_TO_PUBLIC_KEY" {
  description = "Path to the public key used to authenticate to the ELB"
  default     = "mykey.pub"
}

variable "PATH_TO_PRIVATE_KEY" {
  description = "Path to the private key used to authenticate to the ELB"
  default     = "mykey"
}

variable "ECR_APP_IMAGE" {
  description = "Dummy app ECR Image"
  type        = string
}

variable "CONTAINER_NAME" {
  description = "Dummy app container name"
  default     = "dummy-app"
}

variable "CONTAINER_PORT" {
  description = "Dummy app container port"
  default     = 3000
}