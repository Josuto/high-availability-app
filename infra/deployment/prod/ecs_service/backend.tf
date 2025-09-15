terraform {
  backend "s3" {
    bucket         = "josumartinez-terraform-state-bucket" # Must be unique in case of making the bucket public
    key            = "deployment/prod/ecs_service/terraform.tfstate"
    # FIXME: use 'terraform init -backend-config="region=${{ env.AWS_REGION }}"' instead of the region property
    region         = "eu-west-1"
    encrypt        = true # Security best practice
    # dynamodb_table = "josumartinez-terraform-locks" # To prevent state corruption due to simultaneous state update. The DynamoDB table must be created beforehand
  }
}