#!/bin/bash
# Deploy to Production Environment

set -e

echo "🚀 Deploying to PRODUCTION environment..."

# Initialize with production backend
echo "📦 Initializing Terraform with production backend..."
terraform init -backend-config=backend-production.tfbackend -reconfigure

# Plan with production variables
echo "📋 Planning deployment with production configuration..."
terraform plan -var-file=terraform.tfvars.production

# Ask for confirmation
read -p "Deploy to PRODUCTION? This will affect live systems! (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🏗️  Applying production deployment..."
    terraform apply -var-file=terraform.tfvars.production
    echo "✅ Production deployment completed!"
else
    echo "❌ Production deployment cancelled."
fi