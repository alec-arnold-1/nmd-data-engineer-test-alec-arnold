This sets up a private, secure-by-default S3 bucket with the following resources:
- S3 bucket, tagged with `Name`, `Environment` and the provided default tags
- Public access block (blocks all public ACLs and policies)
- Bucket policy denying any request not made over HTTPS
- Ownership controls (`BucketOwnerEnforced`, ACLs disabled; access is controlled only by IAM and bucket policies)

New buckets are encrypted with SSE-S3 by default.

How to use:
```
module "input_bucket" {
  source = "./path-to-this-module"

  bucket_name   = "my-input-bucket"
  env           = "dev"
  force_destroy = true
  default_tags = {
    Owner   = "my-username"
    project = "my-project"
  }
}
```

Inputs:
Name| Description| Type| Required
|--|--|--|--|
bucket_name| Globally unique bucket name. Lowercase letters, numbers and hyphens only (no underscores).| string| Yes
env| Environment name, used for tagging.| string| Yes
default_tags| Tags applied to the bucket.| map(string)| Yes
force_destroy| Allow Terraform to delete the bucket even if it contains objects. Defaults to `true` for this temporary assignment; set `false` in production.| bool| No

Outputs:
Name| Description
|--|--|
bucket_name| Name of the bucket.
bucket_arn| ARN of the bucket.