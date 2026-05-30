provider "aws" { region = "us-west-2" }
data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "tfstate" {
  bucket        = "devsecops-tfstate-${data.aws_caller_identity.current.account_id}"
  force_destroy = false
  tags          = { Name = "devsecops-tfstate" }
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule { apply_server_side_encryption_by_default { sse_algorithm = "AES256" } }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "tfstate_lock" {
  name         = "devsecops-tfstate-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  attribute    { name = "LockID"; type = "S" }
  tags         = { Name = "devsecops-tfstate-lock" }
}

output "s3_bucket" { value = aws_s3_bucket.tfstate.bucket }
output "dynamodb"  { value = aws_dynamodb_table.tfstate_lock.name }
