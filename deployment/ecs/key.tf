resource "aws_key_pair" "my-key-pair" {
  key_name   = "my-key-pair"
  public_key = file(var.PATH_TO_PUBLIC_KEY)
  # Do not update the public key on AWS if it changes locally, thus avoiding potential errors if the key has been inadvertedly updated
  lifecycle {
    ignore_changes = [public_key]
  }
}