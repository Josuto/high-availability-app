terraform {
  backend "s3" {
    bucket         = "josumartinez-terraform-state-bucket" # Must be unique in case of making the bucket public
    key            = "deployment/prod/ecs_service/terraform.tfstate"
    encrypt        = true # Security best practice
    # dynamodb_table = "josumartinez-terraform-locks" # To prevent state corruption due to simultaneous state update. The DynamoDB table must be created beforehand
  }
}