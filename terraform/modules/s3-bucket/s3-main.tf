resource "aws_s3_bucket" "bucket" {
  bucket = var.bucket_name
  tags = merge({
    Name        = var.bucket_name
    Environment = var.env
  }, var.default_tags)
  force_destroy = var.force_destroy
}

# Block public access to the bucket 
resource "aws_s3_bucket_public_access_block" "bucket" { 
  bucket                  = aws_s3_bucket.bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

}

# Create bucket policy: deny any request that isn't made over HTTPS

data "aws_iam_policy_document" "bucket" {
    statement {
        sid = "DenyInsecureTransport"
        effect = "Deny"
        actions = ["s3:*"]
        resources = [
            aws_s3_bucket.bucket.arn,
            "${aws_s3_bucket.bucket.arn}/*",
        ]

        principals {
            type = "*"
            identifiers = ["*"]

        }

        condition {
            test = "Bool"
            variable = "aws:SecureTransport"
            values = ["false"]
        }

    }
}

# Attach the policies to the bucket
resource "aws_s3_bucket_policy" "bucket" { 
    bucket = aws_s3_bucket.bucket.id
    policy = data.aws_iam_policy_document.bucket.json
    
    depends_on = [aws_s3_bucket_public_access_block.bucket]
}



# Disable ACLs: the bucket owner owns every object, and access is
# controlled only by IAM and bucket policies
resource "aws_s3_bucket_ownership_controls" "bucket" {
  bucket = aws_s3_bucket.bucket.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}