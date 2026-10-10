# You will need to modify the key value in the backend block to a unique value for your assignment.

provider "aws" {
  region  = var.region_name
  profile = var.aws_profile
}
data "aws_caller_identity" "current" {}


terraform {
  backend "s3" {
    bucket = "nmd-training-tf-states-888577066340"
    ## update the key value to a unique value for your assignment
    # key            = "assignment/alec-arnold-nmd-assignment.tfstate"
    region         = "us-west-2"
    dynamodb_table = "nmd-training-tf-state-lock-table"
    encrypt        = true # Encrypts the state file at rest
  }
}

