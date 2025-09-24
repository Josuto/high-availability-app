resource "aws_s3_bucket" "josumartinez-terraform-state-bucket" {
  bucket = var.bucket_name
  
  tags = {
    Name    = var.bucket_name
    Project = var.project_name
  }
}