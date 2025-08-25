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
  description = "Dummy app ECR Image. Specified at the infra creation/destruction pipelines"
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

variable "LOG_GROUP" {
  description = "Name of the group to send logs to at AWS Cloudwatch"
  default     = "my-log-group"
}

variable "ALB_RULE_PRIORITY" {
  description = "Priority of the ALB rule (over the default ALB listener)"
  default     = 100 
}

variable "DEREGISTRATION_DELAY" {
  description = "The amount seconds for the ALB to wait before completing the deregistration of a target"
  default     = 30
}

variable "HEALTHCHECK_MATCHER" {
  description = "The expected HTTP response code or codes for a successful health check"
  default     = "200"
}

variable "ACM_CERTIFICATE_DOMAIN" {
  description = "Specifies the domain name of the ACM certificate to retrieve"
  default     = "*.josumartinez.com" 
}

variable "ECS_CLUSTER_NAME" {
  description = "Name of the ECS cluster"
  default     = "my-cluster" 
}

variable "ECS_CLUSTER_ENABLE_SSH" {
  description = "Enable/disable SSH access to the tasks deployed at the ECS cluster"
  default     = true 
}

variable "TASK_ROLE_ARN" {
  description = "Specifies the ARN of an IAM role that the ECS tasks will assume"
  default     = ""
}

variable "ECS_TASK_DESIRED_COUNT" {
  description = "The number of tasks that you want to run for this service"
  default     = 2
}

variable "DEPLOYMENT_MINIMUM_HEALTHY_PERCENT" {
  description = "Lower limit of healthy tasks that must be running during deployment so that the service remains available"
  default     = 100
}

variable "DEPLOYMENT_MAXIMUM_PERCENT" {
  description = "Upper limit of health tasks that must be running during deployment"
  default     = 200
}

variable "root_validation_name" {
  description = "The CNAME name provided by ACM for the root domain."
  type        = string
}

variable "root_validation_value" {
  description = "The CNAME value provided by ACM for the root domain."
  type        = string
}

variable "wildcard_validation_name" {
  description = "The CNAME name provided by ACM for the wildcard subdomain."
  type        = string
}

variable "wildcard_validation_value" {
  description = "The CNAME value provided by ACM for the wildcard subdomain."
  type        = string
}