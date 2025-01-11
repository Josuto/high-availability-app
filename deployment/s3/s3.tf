resource "aws_s3_bucket" "dummy-app-terraform-state-bucket" {
  bucket = "dummy-app-terraform-state-bucket"
  force_destroy = true # Ensures all objects are deleted before the bucket is destroyed
  
  tags = {
    Name = "dummy-app-terraform-state-bucket"
  }
}