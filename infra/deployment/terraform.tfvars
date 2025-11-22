# Central Terraform Variables File
# This file contains common variables used across multiple deployment configurations
# IMPORTANT: Update these values with your own before deploying

# Your root domain name (used for SSL certificates and DNS routing)
root_domain = "josumartinez.com"

# S3 bucket name for Terraform state storage
state_bucket_name = "josumartinez-terraform-state-bucket"

# Project identifier (used for resource tagging and naming)
# hademo = High Availability Demo
project_name = "hademo"

# Environment identifier (dev, prod)
environment = "dev"
