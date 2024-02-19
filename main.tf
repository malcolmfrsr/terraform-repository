resource "aws_s3_bucket" "example" {
  bucket = "mf-bucket"

  tags = {
    Name        = "mf-bucket"
    Environment = "test-account"
  }
}