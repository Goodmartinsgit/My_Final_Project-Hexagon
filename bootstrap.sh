#!/usr/bin/env bash
# =============================================================================
# bootstrap.sh — One-time AWS setup for Hexagon Final Project Terraform state
#
# Run from Git Bash at the project root:
#   bash bootstrap.sh
#
# What it does:
#   1. Creates the S3 bucket that stores Terraform state
#   2. Enables versioning + encryption on that bucket
#   3. Blocks all public access
#   4. Creates a DynamoDB table for Terraform state locking
#
# Safe to re-run — skips resources that already exist.
# =============================================================================

# Full path to aws.exe — avoids PATH issues in Git Bash on Windows.
# Change this if your AWS CLI is installed elsewhere.
AWS="/c/Program Files/Amazon/AWSCLIV2/aws"

# ── Configuration — change PROJECT_NAME to match your project_name variable ──
PROJECT_NAME="hexagon-final-project"
REGION="eu-west-1"
BUCKET="${PROJECT_NAME}-tfstate-$("$AWS" sts get-caller-identity --query Account --output text)"
DYNAMODB_TABLE="${PROJECT_NAME}-tf-locks"

echo ""
echo "=== Step 1: Verifying AWS credentials ==="
"$AWS" sts get-caller-identity

echo ""
echo "=== Step 2: Creating S3 state bucket (skip if exists) ==="
echo "  Bucket name: ${BUCKET}"
if "$AWS" s3api head-bucket --bucket "${BUCKET}" 2>/dev/null; then
  echo "  Bucket '${BUCKET}' already exists — skipping create."
else
  "$AWS" s3api create-bucket \
    --bucket "${BUCKET}" \
    --region "${REGION}" \
    --create-bucket-configuration LocationConstraint="${REGION}"
  echo "  Bucket created."
fi

echo ""
echo "=== Step 3: Enabling bucket versioning ==="
"$AWS" s3api put-bucket-versioning \
  --bucket "${BUCKET}" \
  --versioning-configuration Status=Enabled
echo "  Versioning enabled."

echo ""
echo "=== Step 4: Enabling server-side encryption ==="
"$AWS" s3api put-bucket-encryption \
  --bucket "${BUCKET}" \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
echo "  Encryption enabled."

echo ""
echo "=== Step 5: Blocking all public access ==="
"$AWS" s3api put-public-access-block \
  --bucket "${BUCKET}" \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
echo "  Public access blocked."

echo ""
echo "=== Step 6: Creating DynamoDB lock table (skip if exists) ==="
TABLE_STATUS=$("$AWS" dynamodb describe-table \
  --table-name "${DYNAMODB_TABLE}" \
  --region "${REGION}" \
  --query 'Table.TableStatus' \
  --output text 2>/dev/null || echo "NOT_FOUND")

if [ "${TABLE_STATUS}" != "NOT_FOUND" ]; then
  echo "  DynamoDB table '${DYNAMODB_TABLE}' already exists (status: ${TABLE_STATUS}) — skipping."
else
  "$AWS" dynamodb create-table \
    --table-name "${DYNAMODB_TABLE}" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "${REGION}"
  echo "  DynamoDB table '${DYNAMODB_TABLE}' created."
fi

echo ""
echo "============================================================="
echo " Bootstrap COMPLETE. Resources ready:"
echo "   S3 bucket  : ${BUCKET}"
echo "   Region     : ${REGION}"
echo "   DynamoDB   : ${DYNAMODB_TABLE}"
echo "============================================================="
echo ""
echo ""
