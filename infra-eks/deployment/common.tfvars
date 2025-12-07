# Common Terraform Variables for EKS Infrastructure
# These variables are used across all EKS modules for resource naming and tagging
# IMPORTANT: Update these values with your own before deploying

# Project identifier (used for resource tagging and naming)
project_name = "terraform-course-dummy-nestjs-app"

# Environment identifier (dev, staging, prod)
environment = "prod"

# AWS Region (can also be set via AWS_REGION environment variable)
aws_region = "eu-west-1"
