# Orders analytics pipeline
# A CSV uploaded to the input bucket triggers the Lambda (container image from ECR),
# which writes the analytics reports as partitioned CSVs to the output bucket,
# and the order counts as a partitioned Glue table.
#
# Modules:   input/output S3 buckets, ECR repo, Lambda (incl. its IAM role and log group)
# This file: S3 trigger, Lambda invoke permission, Glue database, least privilege IAM policy for the Lambda role

module "lambda_function" {
  source                = "../modules/lambda"
  lambda_name           = "${local.app_name}-file-processor"
  role_name             = "${local.app_name}-file-processor-role"
  log_retention_in_days = 14
  image_uri             = "${module.ecr_repo.repository_url}:latest"
  timeout               = 60
  memory_size           = 512
  environment_variables = {
    OUTPUT_BUCKET = module.output_bucket.bucket_name,
    GLUE_DATABASE = aws_glue_catalog_database.analytics.name
  }

  default_tags = local.default_tags
}

module "ecr_repo" {
  source       = "../modules/ecr-repo"
  repo_name    = "${local.app_name}-ecr"
  default_tags = local.default_tags
}

resource "aws_lambda_permission" "allow_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda_function.lambda_arn
  principal     = "s3.amazonaws.com"
  source_arn    = module.input_bucket.bucket_arn
}

resource "aws_s3_bucket_notification" "s3_notification" {
  bucket = module.input_bucket.bucket_name
  lambda_function {
    lambda_function_arn = module.lambda_function.lambda_arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".csv" # removed filter prefix for s3 wildcard reasons
  }
  depends_on = [aws_lambda_permission.allow_bucket] # set up s3 trigger after lambda permission
}

resource "aws_glue_catalog_database" "analytics" {
  name = "${local.app_name}-order-analytics"
  tags = local.default_tags
}

module "input_bucket" {
  source       = "../modules/s3-bucket"
  bucket_name  = "${replace(local.app_name, "_", "-")}-input-bucket" # Using replace to counteract s3 not allowing underscore
  env          = var.env
  default_tags = local.default_tags
}

module "output_bucket" {
  source       = "../modules/s3-bucket"
  bucket_name  = "${replace(local.app_name, "_", "-")}-output-bucket" # Using replace to counteract s3 not allowing underscore
  env          = var.env
  default_tags = local.default_tags
}

# IAM policies that follow the principle of least privilege as asked for in instructions.md
# needs to read input, write output, and manage the glue table

resource "aws_iam_role_policy" "lambda_access" {
  name = "${local.app_name}-lambda-access"
  role = module.lambda_function.role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ReadInputFiles"
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${module.input_bucket.bucket_arn}/*"
      },
      {
        Sid      = "ListOutputBucket"
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = module.output_bucket.bucket_arn
      },
      {
        Sid      = "WriteOutputFiles"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = "${module.output_bucket.bucket_arn}/*"
      },
      {
        Sid    = "ManageGlueTable"
        Effect = "Allow"
        Action = [
          "glue:GetDatabase",
          "glue:GetTable", "glue:CreateTable", "glue:UpdateTable",
          "glue:GetPartition", "glue:GetPartitions",
          "glue:CreatePartition", "glue:BatchCreatePartition", "glue:UpdatePartition"
        ]
        Resource = [
          "arn:aws:glue:${var.region_name}:${data.aws_caller_identity.current.account_id}:catalog",
          "arn:aws:glue:${var.region_name}:${data.aws_caller_identity.current.account_id}:database/${aws_glue_catalog_database.analytics.name}",
          "arn:aws:glue:${var.region_name}:${data.aws_caller_identity.current.account_id}:table/${aws_glue_catalog_database.analytics.name}/*"
        ]
      }
    ]
  })
}