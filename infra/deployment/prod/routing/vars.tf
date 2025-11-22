variable "state_bucket_name" {
  description = "The name of the S3 bucket specifiying the Terraform state"
  type        = string
}

variable "root_domain" {
  description = "The root domain name (e.g., example.com)"
  type        = string
}
