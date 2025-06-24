#!/bin/bash
# Deploy to Staging Environment

set -e

echo "🚀 Deploying to STAGING environment..."

# Initialize with staging backend
echo "📦 Initializing Terraform with staging backend..."
terraform init -backend-config=backend-staging.tfbackend -reconfigure

# Plan with staging variables
echo "📋 Planning deployment with staging configuration..."
terraform plan -var-file=terraform.tfvars.staging

# Ask for confirmation
read -p "Deploy to staging? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🏗️  Applying staging deployment..."
    terraform apply -var-file=terraform.tfvars.staging -auto-approve
    echo "✅ Staging deployment completed!"
else
    echo "❌ Staging deployment cancelled."
fi