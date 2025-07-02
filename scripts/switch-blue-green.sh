#!/bin/bash
# Blue-Green Deployment Switching Script
# Usage: ./switch-blue-green.sh <environment> <target-group>
# Example: ./switch-blue-green.sh production green

set -e

# Validate arguments
if [ $# -ne 2 ]; then
    echo "Usage: $0 <environment> <target-group>"
    echo "  environment: staging or production"
    echo "  target-group: blue or green"
    exit 1
fi

ENVIRONMENT=$1
TARGET_GROUP=$2

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(staging|production)$ ]]; then
    echo "❌ Environment must be 'staging' or 'production'"
    exit 1
fi

# Validate target group
if [[ ! "$TARGET_GROUP" =~ ^(blue|green)$ ]]; then
    echo "❌ Target group must be 'blue' or 'green'"
    exit 1
fi

echo "🔄 Switching $ENVIRONMENT to $TARGET_GROUP target group..."

# Select workspace
echo "📁 Selecting $ENVIRONMENT workspace..."
terraform workspace select $ENVIRONMENT

# Get current Terraform outputs
echo "📊 Getting current infrastructure details..."
LISTENER_ARN=$(terraform output -raw alb_https_listener_arn 2>/dev/null || echo "")
BLUE_TG_ARN=$(terraform output -raw blue_target_group_arn 2>/dev/null || echo "")
GREEN_TG_ARN=$(terraform output -raw green_target_group_arn 2>/dev/null || echo "")

# Validate outputs
if [ -z "$LISTENER_ARN" ] || [ -z "$BLUE_TG_ARN" ] || [ -z "$GREEN_TG_ARN" ]; then
    echo "❌ Error: Could not retrieve required ARNs from Terraform outputs"
    echo "   Listener ARN: $LISTENER_ARN"
    echo "   Blue TG ARN: $BLUE_TG_ARN"
    echo "   Green TG ARN: $GREEN_TG_ARN"
    echo ""
    echo "💡 Possible causes:"
    echo "   - Blue-green deployment not enabled (blue_green_enabled = false)"
    echo "   - Terraform changes not applied yet"
    echo "   - Wrong workspace selected"
    exit 1
fi

# Determine target ARN
if [ "$TARGET_GROUP" == "blue" ]; then
    TARGET_ARN=$BLUE_TG_ARN
    echo "🔵 Switching to BLUE target group"
else
    TARGET_ARN=$GREEN_TG_ARN
    echo "🟢 Switching to GREEN target group"
fi

# Check current target group health
echo "🏥 Checking $TARGET_GROUP target group health..."
HEALTHY_COUNT=$(aws elbv2 describe-target-health \
    --target-group-arn $TARGET_ARN \
    --query "length(TargetHealthDescriptions[?TargetHealth.State=='healthy'])" \
    --output text)

TOTAL_COUNT=$(aws elbv2 describe-target-health \
    --target-group-arn $TARGET_ARN \
    --query "length(TargetHealthDescriptions)" \
    --output text)

echo "   Healthy targets: $HEALTHY_COUNT/$TOTAL_COUNT"

if [ "$HEALTHY_COUNT" -eq 0 ]; then
    echo "⚠️  Warning: No healthy targets in $TARGET_GROUP group!"
    read -p "   Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Aborted"
        exit 1
    fi
fi

# Get current listener configuration
echo "📋 Getting current listener configuration..."
CURRENT_TG=$(aws elbv2 describe-listeners \
    --listener-arns $LISTENER_ARN \
    --query "Listeners[0].DefaultActions[0].TargetGroupArn" \
    --output text)

if [ "$CURRENT_TG" == "$TARGET_ARN" ]; then
    echo "✅ Already routing to $TARGET_GROUP target group"
    exit 0
fi

# Switch traffic
echo "🚦 Switching traffic to $TARGET_GROUP target group..."
aws elbv2 modify-listener \
    --listener-arn $LISTENER_ARN \
    --default-actions Type=forward,TargetGroupArn=$TARGET_ARN

if [ $? -eq 0 ]; then
    echo "✅ Successfully switched to $TARGET_GROUP target group!"
    
    # Update Terraform variable for consistency
    echo "📝 Updating Terraform configuration..."
    if [ -f "terraform.tfvars.$ENVIRONMENT" ]; then
        # Update active_target_group in tfvars
        if grep -q "active_target_group" "terraform.tfvars.$ENVIRONMENT"; then
            sed -i.bak "s/active_target_group.*=.*/active_target_group = \"$TARGET_GROUP\"/" "terraform.tfvars.$ENVIRONMENT"
        else
            echo "active_target_group = \"$TARGET_GROUP\"" >> "terraform.tfvars.$ENVIRONMENT"
        fi
        echo "✅ Updated terraform.tfvars.$ENVIRONMENT"
    fi
    
    # Show current routing status
    echo ""
    echo "📊 Current routing status:"
    echo "   Environment: $ENVIRONMENT"
    echo "   Active Target Group: $TARGET_GROUP"
    echo "   Target Group ARN: $TARGET_ARN"
    
    # Monitor health for 30 seconds
    echo ""
    echo "🔍 Monitoring health for 30 seconds..."
    for i in {1..6}; do
        sleep 5
        HEALTHY=$(aws elbv2 describe-target-health \
            --target-group-arn $TARGET_ARN \
            --query "length(TargetHealthDescriptions[?TargetHealth.State=='healthy'])" \
            --output text)
        echo "   Health check $i/6: $HEALTHY healthy targets"
    done
    
    echo ""
    echo "🎉 Blue-green switch completed successfully!"
else
    echo "❌ Failed to switch traffic!"
    exit 1
fi