#!/bin/bash
# Switch between environments without deployment

set -e

if [ -z "$1" ]; then
    echo "Usage: ./switch-env.sh [staging|production]"
    echo "This script switches your Terraform backend without deploying."
    exit 1
fi

ENVIRONMENT=$1

case $ENVIRONMENT in
    staging)
        echo "🔄 Switching to STAGING environment..."
        terraform init -backend-config=backend-staging.tfbackend -reconfigure
        echo "✅ Switched to staging. Use 'terraform plan -var-file=terraform.tfvars.staging' to plan."
        ;;
    production)
        echo "🔄 Switching to PRODUCTION environment..."
        terraform init -backend-config=backend-production.tfbackend -reconfigure
        echo "✅ Switched to production. Use 'terraform plan -var-file=terraform.tfvars.production' to plan."
        ;;
    *)
        echo "❌ Invalid environment. Use 'staging' or 'production'"
        exit 1
        ;;
esac