# Backend Configuration File
# This file contains the S3 backend configuration that should be passed to terraform init
# Usage: terraform init -backend-config=backend-config.hcl
#
# IMPORTANT: Update the 'bucket' value below with your own S3 bucket name before use.
# This bucket must be created first using the infrastructure in ./backend/

bucket = "josumartinez-terraform-state-bucket"

# Optional: Uncomment the following line if you have DynamoDB state locking enabled
# dynamodb_table = "josumartinez-terraform-locks"
