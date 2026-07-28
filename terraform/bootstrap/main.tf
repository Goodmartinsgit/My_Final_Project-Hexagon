# Run this FIRST, with local state, before touching the main config.
# terraform init && terraform apply
# Then copy the bucket name from the output into ../main.tf's backend block
# and run `terraform init -reconfigure` there.
#
# Alternatively, use the bootstrap.sh script at the project root — it does
# the same thing with the AWS CLI and does not require Terraform to be initialised first.

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "project_name" {
  description = "Short name prefix used to name the state bucket and lock table. Must match var.project_name in the root module."
  type        = string
  default     = "hexagon-final-project"
}

variable "region" {
  description = "AWS region in which to create the state bucket and lock table."
  type        = string
  default     = "eu-west-1"
}

provider "aws" {
  region = var.region
}

# S3 bucket — name is globally unique because it includes the AWS account ID.
resource "aws_s3_bucket" "tfstate" {
  bucket = "${var.project_name}-tfstate-${data.aws_caller_identity.current.account_id}"

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name      = "${var.project_name}-tfstate"
    ManagedBy = "Terraform"
  }
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

# DynamoDB lock table
resource "aws_dynamodb_table" "locks" {
  name         = "${var.project_name}-tf-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name      = "${var.project_name}-tf-locks"
    ManagedBy = "Terraform"
  }
}

data "aws_caller_identity" "current" {}

output "state_bucket_name" {
  description = "Copy this value into the bucket field of terraform/main.tf's backend block."
  value       = aws_s3_bucket.tfstate.bucket
}

output "dynamodb_table_name" {
  description = "Copy this value into the dynamodb_table field of terraform/main.tf's backend block."
  value       = aws_dynamodb_table.locks.name
}
