# NMD Orders Analytics Pipeline

This project is a serverless pipeline where a CSV of orders gets uploaded to the input S3 bucket. This then triggers a dockerized Lambda that computes 3 analytics reports and writes them as CSVs into the output S3 bucket. The order counts report is also written as a partitioned AWS glue table.

## Architecture

input bucket -> Lambda (container image from ECR) -> output bucket

| Resource | Name | Defined in |
|---|---|---|
| Input bucket | `nmd-assignment-alec-arnold-input-bucket` | `modules/s3-bucket` |
| Output bucket | `nmd-assignment-alec-arnold-output-bucket` | `modules/s3-bucket` |
| ECR repo | `nmd-assignment-alec_arnold-ecr` | `modules/ecr-repo` |
| Lambda + IAM role + log group | `nmd-assignment-alec_arnold-file-processor` | `modules/lambda` |
| Glue database | `nmd-assignment-alec_arnold-order-analytics` | `assignment/main.tf` |
| S3 trigger, Lambda permission, IAM policy | n/a | `assignment/main.tf` |

## Data reports

| Report | Output path |
|---|---|
| Most profitable region and its profit | `top_region/source_file=<input name>/top_region.csv` |
| Most common ship mode per category | `top_ship/source_file=<input name>/top_ship.csv` |
| Order count per category and sub category | `order_counts/source_file=<input name>/order_counts.csv` |
| Order counts as a Glue table (`order_counts`) | `order_counts_glue/source_file=<input name>/*.snappy.parquet` |

## Partitioning

I made it so that each input file's results go into their own folder so that if you were to upload another input csv file, the results from the previous input file would not get overwritten.

## Design choices

### orders_analytics.py

Profit is calculated with (List Price x (1- Discount Percent / 100) - cost price) x Quantity

For ship mode, the most common shipping method per category could have a tie in frequency count. For these cases I list both methods in the column separated by a semicolon. They are sorted alphabetically.
I believe this to be the best approach because the cell can be kept as a string this way which is good for CSV format.

Order counts: Finding the number of orders for each category and sub category is interpreted as the 
number of unique order ids (orders) for each sub category with its respective category also in the dataframe.

### Lambda

The input bucket is read from the S3 event. OUTPUT_BUCKET and GLUE_DATABASE are passed as environment variables.

Timeout changed to 60s and memory changed to 512 MB. awswrangler cold start made 15 second timeout too short.

### Terraform

Modularity: 's3-bucket', 'ecr-repo', and 'lambda' are reusable modules. I added an 'architectures' variable to the lambda module so that it isnt hardcoded and can match the arm64 docker build platform from the example build command in instructions.md. s3-main.tf: force_destroy = true so that terraform destroy can delete the bucket even if it has files. (everything for assignment is temporary I assume)

S3 trigger: removed filter_prefix = "*" in main.tf because wildcards arent supported by S3 filters.
The trigger uses filter_suffix = ".csv" and depends_on the lambda permission.


## Security/policies

Least privilege IAM for the lambda: read objects from the input bucket only, list/read/write/delete
in the output bucket, create and update ttables and partitions in its own Glue database only, 
cloudwatch logs through AWSLambdaBasicExecutionRole.

Buckets: all public access blocked, explicitly showing ACLs disabled, and a bucket policy that denies any
non HTTPS request.

## Deploy

Prerequisites: Terraform, docker desktop, AWS CLI with a profile for the assessment.

1. Set candidate_name (exact AWS IAM username) and aws_profile in terraform/assignment/vars.tfvars

2. Initialize terraform. I had to use the key assignment/alec-arnold-key-nmd-assignment.tfstate instead of the example in instructions.md
```sh
cd terraform/assignment
terraform init -backend-config="key=assignment/alec-arnold-key-nmd-assignment.tfstate"
```

3. Create the ECR repo
```sh
terraform apply -var-file="vars.tfvars" -target=module.ecr_repo
```

4. Build and push the image. 
```sh
export AWS_PROFILE=<profile>
LOCAL_IMAGE_NAME=nmd-lambda
AWS_ACCOUNT_ID=888577066340
REGION=us-west-2
ECR_URI=$AWS_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/nmd-assignment-alec_arnold-ecr

docker build --platform linux/arm64 --no-cache --provenance=false -t "$LOCAL_IMAGE_NAME" .
aws ecr get-login-password | docker login --username AWS --password-stdin "$AWS_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"
docker tag "$LOCAL_IMAGE_NAME" "$ECR_URI"
docker push "$ECR_URI"
```

5. Deploy everything else
```sh
terraform apply -var-file="vars.tfvars"
```

6. After pushing a new image to an existing lambda, you will need to force an update.
```sh
aws lambda update-function-code --function-name nmd-assignment-alec_arnold-file-processor --image-uri "$ECR_URI:latest"
```

## Testing

sample_orders.csv is in the repo root.

Upload the test file to trigger the pipeline
```sh
aws s3 cp sample_orders.csv s3://nmd-assignment-alec-arnold-input-bucket/
```
Check the output files
```sh
aws s3 ls s3://nmd-assignment-alec-arnold-output-bucket/ --recursive
```
Read a report's contents
```sh
aws s3 cp s3://nmd-assignment-alec-arnold-output-bucket/top_region/source_file=sample_orders/top_region.csv - 
```
Confirm the lambda created the order_counts table in the glue database
```sh
aws glue get-tables --database-name nmd-assignment-alec_arnold-order-analytics --query "TableList[].Name"
```
List the registered partitions.
```sh
aws glue get-partitions --database-name nmd-assignment-alec_arnold-order-analytics --table-name order_counts --query "Partitions[].Values"
```
