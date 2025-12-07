# Backend Configuration File for EKS Infrastructure
# This file contains the S3 backend configuration that should be passed to terraform init
# Usage: terraform init -backend-config=backend-config.hcl
#
# IMPORTANT: Update the 'bucket' value below with your own S3 bucket name before use.
# This bucket must be created first using the infrastructure in infra/deployment/backend/

bucket = "YOUR_TERRAFORM_STATE_BUCKET_NAME"

# Optional: Uncomment the following line if you have DynamoDB state locking enabled
# dynamodb_table = "terraform_locks"
