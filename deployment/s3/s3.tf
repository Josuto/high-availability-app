resource "aws_s3_bucket" "dummy-app-terraform-state-bucket" {
  bucket = "dummy-app-terraform-state-bucket"
  
  tags = {
    Name = "dummy-app-terraform-state-bucket"
  }
}