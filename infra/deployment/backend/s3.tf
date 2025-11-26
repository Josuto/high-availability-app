resource "aws_s3_bucket" "terraform_state_bucket" {
  bucket = var.state_bucket_name

  tags = {
    Name        = var.state_bucket_name
    Project     = var.project_name
    Environment = var.environment
  }
}

# Enable versioning on the S3 bucket to maintain a history of state file versions.
# This is critical for disaster recovery: if the state file is accidentally deleted or corrupted,
# you can restore a previous version. Versioning also allows you to audit changes over time.
resource "aws_s3_bucket_versioning" "state_versioning" {
  bucket = aws_s3_bucket.terraform_state_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enforce server-side encryption for objects stored in the state bucket based on environment.
# In production, encryption is mandatory to protect sensitive infrastructure state data.
# In dev, encryption can be optionally disabled for troubleshooting or cost reasons, though
# it's generally recommended to keep it enabled even in non-production environments.
# Note: The backend configuration `encrypt = true` encrypts during transit; this ensures
# encryption at rest within the bucket itself, preventing unencrypted uploads.
resource "aws_s3_bucket_server_side_encryption_configuration" "state_encryption" {
  count  = var.environment == "prod" ? 1 : 0
  bucket = aws_s3_bucket.terraform_state_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256" # Use AWS-managed keys (SSE-S3) for automatic encryption
    }
    bucket_key_enabled = true # Reduces encryption costs by minimizing KMS requests
  }
}

# Block all public access to the state bucket to prevent accidental exposure.
# Terraform state files contain sensitive information (resource IDs, configurations,
# and potentially secrets), so they must never be publicly accessible. This resource
# applies multiple layers of protection against public access through ACLs or bucket policies.
resource "aws_s3_bucket_public_access_block" "state_bucket_pab" {
  bucket = aws_s3_bucket.terraform_state_bucket.id

  block_public_acls       = true # Reject PUT requests that specify a public ACL
  block_public_policy     = true # Reject PUT requests that would make the bucket public via policy
  ignore_public_acls      = true # Ignore any existing public ACLs on the bucket
  restrict_public_buckets = true # Block public access granted through bucket or access point policies
}

# Lifecycle policy to automatically delete old state file versions after a retention period.
# This prevents the bucket from growing indefinitely due to versioning, while maintaining
# a reasonable history for rollback and audit purposes. Dev uses a shorter retention (30 days)
# for cost savings, while prod retains versions for 90 days to support longer audit trails.
resource "aws_s3_bucket_lifecycle_configuration" "state_lifecycle" {
  bucket = aws_s3_bucket.terraform_state_bucket.id

  rule {
    id     = "delete-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = try({ dev = 30, prod = 90 }[var.environment], 90)
    }
  }
}
