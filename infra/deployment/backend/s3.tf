resource "aws_s3_bucket" "josumartinez-terraform-state-bucket" {
  bucket = "josumartinez-terraform-state-bucket"
  
  tags = {
    Name = "josumartinez-terraform-state-bucket"
  }
}