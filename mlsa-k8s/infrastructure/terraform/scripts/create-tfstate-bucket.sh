#!/bin/bash
# Create GCS bucket for Terraform state (run ONCE before terraform init)

set -e

PROJECT_ID=${1:-mlsa-k8s-capstone}
BUCKET_NAME="mlsa-k8s-tfstate"
REGION="asia-southeast1"

echo "🪣 Creating GCS bucket for Terraform state..."
echo "   Project: $PROJECT_ID"
echo "   Bucket: gs://$BUCKET_NAME"
echo "   Region: $REGION"

# Create bucket with uniform access
gsutil mb -p $PROJECT_ID -c STANDARD -l $REGION gs://$BUCKET_NAME

# Enable versioning for safety
gsutil versioning set on gs://$BUCKET_NAME

# Enable uniform bucket-level access
gsutil uniformbucketlevelaccess set on gs://$BUCKET_NAME

echo "✅ Bucket created successfully!"
echo ""
echo "Next steps:"
echo "  1. cd infrastructure/terraform"
echo "  2. terraform init"
echo "  3. terraform plan"
echo "  4. terraform apply"
