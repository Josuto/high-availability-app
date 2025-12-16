# Backend Configuration Variables
# These variables are used to configure the S3 bucket for Terraform state storage
# IMPORTANT: Update the state_bucket_name with your own unique bucket name

# Name of the S3 bucket for storing Terraform state
# Must be globally unique across all AWS accounts
state_bucket_name = "josumartinez-terraform-state-bucket"

# Optional: DynamoDB table name for state locking
# Uncomment if you want to enable state locking
# dynamodb_table_name = "terraform-state-locks"
