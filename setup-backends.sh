#!/bin/bash
# Setup S3 backends and DynamoDB tables for multi-environment deployment

set -e

REGION="us-west-2"

echo "🚀 Setting up Terraform backends for multi-environment deployment..."

# Function to create S3 bucket
create_s3_bucket() {
    local bucket_name=$1
    local env=$2
    
    echo "📦 Creating S3 bucket: $bucket_name"
    
    # Check if bucket exists
    if aws s3api head-bucket --bucket "$bucket_name" 2>/dev/null; then
        echo "✅ S3 bucket $bucket_name already exists"
    else
        # Create bucket
        aws s3api create-bucket \
            --bucket "$bucket_name" \
            --region "$REGION" \
            --create-bucket-configuration LocationConstraint="$REGION"
        
        # Enable versioning
        aws s3api put-bucket-versioning \
            --bucket "$bucket_name" \
            --versioning-configuration Status=Enabled
        
        # Enable server-side encryption
        aws s3api put-bucket-encryption \
            --bucket "$bucket_name" \
            --server-side-encryption-configuration '{
                "Rules": [
                    {
                        "ApplyServerSideEncryptionByDefault": {
                            "SSEAlgorithm": "AES256"
                        }
                    }
                ]
            }'
        
        # Block public access
        aws s3api put-public-access-block \
            --bucket "$bucket_name" \
            --public-access-block-configuration \
                BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
        
        echo "✅ S3 bucket $bucket_name created and configured"
    fi
}

# Function to create DynamoDB table
create_dynamodb_table() {
    local table_name=$1
    local env=$2
    
    echo "🗃️  Creating DynamoDB table: $table_name"
    
    # Check if table exists
    if aws dynamodb describe-table --table-name "$table_name" --region "$REGION" 2>/dev/null >/dev/null; then
        echo "✅ DynamoDB table $table_name already exists"
    else
        # Create table
        aws dynamodb create-table \
            --table-name "$table_name" \
            --attribute-definitions AttributeName=LockID,AttributeType=S \
            --key-schema AttributeName=LockID,KeyType=HASH \
            --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
            --region "$REGION" \
            --tags Key=Environment,Value="$env" Key=Purpose,Value="TerraformStateLock"
        
        echo "⏳ Waiting for DynamoDB table $table_name to be active..."
        aws dynamodb wait table-exists --table-name "$table_name" --region "$REGION"
        
        echo "✅ DynamoDB table $table_name created"
    fi
}

# Create staging backend infrastructure
echo ""
echo "🎯 Setting up STAGING backend..."
create_s3_bucket "remote-backend-mht" "staging"
create_dynamodb_table "remote-backend-mht" "staging"

# Create production backend infrastructure  
echo ""
echo "🎯 Setting up PRODUCTION backend..."
create_s3_bucket "remote-backend-mht" "production"
create_dynamodb_table "remote-backend-mht" "production"

echo ""
echo "✅ All backend infrastructure created successfully!"
echo ""
echo "📋 Backend Configuration Summary:"
echo "Shared Resources:"
echo "  S3 Bucket: remote-backend-mht"
echo "  DynamoDB: remote-backend-mht"
echo "  Staging Key: staging/terraform.tfstate"
echo "  Production Key: production/terraform.tfstate"
echo ""
echo "🚀 You can now run:"
echo "  ./deploy-staging.sh"
echo "  ./deploy-production.sh"