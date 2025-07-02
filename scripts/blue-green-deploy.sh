#!/bin/bash
# Blue-Green deployment script
# Usage: ./blue-green-deploy.sh <environment> <service>
# Examples:
#   ./blue-green-deploy.sh staging be
#   ./blue-green-deploy.sh staging fe
#   ./blue-green-deploy.sh production be
#   ./blue-green-deploy.sh production fe

set -e

ENVIRONMENT=$1
SERVICE=$2

# Validate parameters
if [ -z "$ENVIRONMENT" ] || [ -z "$SERVICE" ]; then
    echo "❌ Usage: $0 <environment> <service>"
    echo "   Environment: staging | production"
    echo "   Service: be | fe"
    echo ""
    echo "Examples:"
    echo "   $0 staging be    # Deploy backend to staging"
    echo "   $0 staging fe    # Deploy frontend to staging"
    echo "   $0 production be # Deploy backend to production"
    exit 1
fi

if [[ ! "$ENVIRONMENT" =~ ^(staging|production)$ ]]; then
    echo "❌ Environment must be 'staging' or 'production'"
    exit 1
fi

if [[ ! "$SERVICE" =~ ^(be|fe)$ ]]; then
    echo "❌ Service must be 'be' (backend) or 'fe' (frontend)"
    exit 1
fi

# Configuration based on environment and service
case $ENVIRONMENT in
    "staging")
        case $SERVICE in
            "be")
                IMAGE="rollg/go-gin-app:latest"
                CONTAINER="mht-api-app"
                PORT="8080"
                TEMP_PORT="9080"
                SERVICE_NAME="Backend"
                ;;
            "fe")
                IMAGE="rollg/mht-front-end:latest"
                CONTAINER="mht-ui-app"
                PORT="3030"
                TEMP_PORT="4030"
                SERVICE_NAME="Frontend"
                ;;
        esac
        TFVARS_FILE="terraform.tfvars.staging"
        ;;
    "production")
        case $SERVICE in
            "be")
                IMAGE="rollg/go-gin-app:latest"
                CONTAINER="mht-api-app"
                PORT="8080"
                TEMP_PORT="9080"
                SERVICE_NAME="Backend"
                ;;
            "fe")
                IMAGE="rollg/mht-front-end:latest"
                CONTAINER="mht-ui-app"
                PORT="3030"
                TEMP_PORT="4030"
                SERVICE_NAME="Frontend"
                ;;
        esac
        TFVARS_FILE="terraform.tfvars.production"
        ;;
esac

echo "🚀 Starting Blue-Green $SERVICE_NAME deployment for $ENVIRONMENT environment..."

# Switch to correct workspace
echo "📁 Selecting $ENVIRONMENT workspace..."
terraform workspace select $ENVIRONMENT

# Check if blue-green is enabled
BLUE_GREEN_ENABLED=$(terraform output -json deployment_status 2>/dev/null | jq -r '.blue_green_enabled' 2>/dev/null || echo "false")

if [ "$BLUE_GREEN_ENABLED" != "true" ]; then
    echo "⚠️  Blue-green deployment is not enabled for $ENVIRONMENT"
    echo "💡 Falling back to standard rolling deployment"
    exec ./scripts/redeploy.sh $ENVIRONMENT $SERVICE
fi

# Get current active target group
ACTIVE_TG=$(terraform output -json deployment_status 2>/dev/null | jq -r '.active_target_group' 2>/dev/null || echo "blue")
echo "📊 Current active target group: $ACTIVE_TG"

# Determine inactive target group
if [ "$ACTIVE_TG" = "blue" ]; then
    INACTIVE_TG="green"
else
    INACTIVE_TG="blue"
fi

echo "🎯 Will deploy to inactive target group: $INACTIVE_TG"

# Get instance IPs for the inactive target group
echo "🔍 Getting instances in $INACTIVE_TG target group..."

# Get target group ARN for inactive group
if [ "$INACTIVE_TG" = "blue" ]; then
    TG_ARN=$(terraform output -raw blue_target_group_arn)
else
    TG_ARN=$(terraform output -raw green_target_group_arn)
fi

# Get instance IDs from the target group
INSTANCE_IDS=$(aws elbv2 describe-target-health \
    --target-group-arn "$TG_ARN" \
    --region $(terraform output -raw region 2>/dev/null || echo "us-west-2") \
    --query 'TargetHealthDescriptions[*].Target.Id' \
    --output text)

if [ -z "$INSTANCE_IDS" ]; then
    echo "❌ No instances found in $INACTIVE_TG target group"
    echo "💡 Make sure instances are attached to both target groups"
    exit 1
fi

echo "📍 Found instances: $INSTANCE_IDS"

# Get instance IPs
INSTANCE_IPS=()
for INSTANCE_ID in $INSTANCE_IDS; do
    IP=$(aws ec2 describe-instances \
        --instance-ids $INSTANCE_ID \
        --region $(terraform output -raw region 2>/dev/null || echo "us-west-2") \
        --query 'Reservations[0].Instances[0].PublicIpAddress' \
        --output text)
    INSTANCE_IPS+=($IP)
done

echo "📍 Instance IPs in $INACTIVE_TG group: ${INSTANCE_IPS[@]}"

# Function to deploy to a single instance
deploy_to_instance() {
    local IP=$1
    local INSTANCE_NUM=$2
    
    echo "📦 Deploying $SERVICE_NAME to $INACTIVE_TG instance $INSTANCE_NUM ($IP)..."
    
    # Copy .env file if it exists
    ENV_FILE=""
    for path in "../.env" "../../.env" ".env"; do
        if [ -f "$path" ]; then
            ENV_FILE="$path"
            break
        fi
    done
    
    if [ -n "$ENV_FILE" ]; then
        echo "📁 Copying .env file..."
        scp -i ~/.ssh/id_rsa_github "$ENV_FILE" ubuntu@$IP:/home/ubuntu/.env
        ssh -i ~/.ssh/id_rsa_github ubuntu@$IP "chmod 600 /home/ubuntu/.env"
    fi
    
    # Deploy the service
    ssh -i ~/.ssh/id_rsa_github ubuntu@$IP << EOF
        set -e
        
        echo "📥 Pulling latest $SERVICE_NAME image..."
        sudo docker pull $IMAGE
        
        echo "🧹 Cleaning up any existing containers..."
        sudo docker stop ${CONTAINER}_new || true
        sudo docker rm ${CONTAINER}_new || true
        sudo docker stop ${CONTAINER}_final || true
        sudo docker rm ${CONTAINER}_final || true
        
        echo "🆕 Starting new container on port $TEMP_PORT..."
        sudo docker run -d --name ${CONTAINER}_new \\
            -p $TEMP_PORT:$(if [ "$SERVICE" = "fe" ]; then echo "3030"; else echo "$PORT"; fi) \\
            --env-file /home/ubuntu/.env \\
            $IMAGE
        
        echo "⏳ Waiting for new container to be ready..."
        sleep 15
        
        # Health check
        for i in \$(seq 1 12); do
            $(if [ "$SERVICE" = "be" ]; then
                echo "if curl -f http://localhost:$TEMP_PORT/health > /dev/null 2>&1; then"
            else
                echo "if curl -f http://localhost:$TEMP_PORT > /dev/null 2>&1; then"
            fi)
                echo "✅ Health check passed"
                break
            fi
            if [ \$i -eq 12 ]; then
                echo "❌ Health check failed after 60 seconds"
                sudo docker stop ${CONTAINER}_new || true
                sudo docker rm ${CONTAINER}_new || true
                exit 1
            fi
            echo "⏳ Health check attempt \$i/12 failed, retrying in 5 seconds..."
            sleep 5
        done
        
        echo "🔄 Switching nginx to new container..."
        sudo cp /etc/nginx/sites-available/default /etc/nginx/sites-available/default.backup
        sudo sed -i "s/:$PORT/:$TEMP_PORT/g" /etc/nginx/sites-available/default
        sudo nginx -t && sudo systemctl reload nginx
        
        echo "🗑️ Stopping old container..."
        sudo docker stop $CONTAINER || true
        sudo docker rm $CONTAINER || true
        
        echo "🔄 Starting final container on correct port..."
        FINAL_INTERNAL_PORT=$(if [ "$SERVICE" = "fe" ]; then echo "3030"; else echo "$PORT"; fi)
        sudo docker run -d --name ${CONTAINER}_final \\
            -p $PORT:\$FINAL_INTERNAL_PORT \\
            --env-file /home/ubuntu/.env \\
            $IMAGE
        
        echo "🔄 Switching nginx to final container..."
        sudo sed -i "s/:$TEMP_PORT/:$PORT/g" /etc/nginx/sites-available/default
        sudo nginx -t && sudo systemctl reload nginx
        
        echo "🗑️ Cleaning up temporary container..."
        sudo docker stop ${CONTAINER}_new || true
        sudo docker rm ${CONTAINER}_new || true
        
        echo "🔄 Renaming final container..."
        sudo docker rename ${CONTAINER}_final $CONTAINER
        
        echo "✅ Deployment complete on $INACTIVE_TG instance"
EOF
    
    if [ $? -eq 0 ]; then
        echo "✅ Instance $INSTANCE_NUM ($IP) - SUCCESS"
        return 0
    else
        echo "❌ Instance $INSTANCE_NUM ($IP) - FAILED"
        return 1
    fi
}

# Deploy to all instances in the inactive target group
SUCCESS_COUNT=0
TOTAL_COUNT=${#INSTANCE_IPS[@]}

for i in "${!INSTANCE_IPS[@]}"; do
    INSTANCE_NUM=$((i + 1))
    if deploy_to_instance "${INSTANCE_IPS[$i]}" "$INSTANCE_NUM"; then
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    fi
    echo ""
done

echo "🎉 Deployment to $INACTIVE_TG target group complete!"
echo "✅ Successful deployments: $SUCCESS_COUNT/$TOTAL_COUNT"

if [ $SUCCESS_COUNT -ne $TOTAL_COUNT ]; then
    echo "⚠️  Some deployments failed. Check the logs above."
    exit 1
fi

# Wait for target group to be healthy
echo "⏳ Waiting for $INACTIVE_TG target group to be healthy..."
sleep 30

# Check health of inactive target group
HEALTHY_COUNT=$(aws elbv2 describe-target-health \
    --target-group-arn "$TG_ARN" \
    --region $(terraform output -raw region 2>/dev/null || echo "us-west-2") \
    --query 'TargetHealthDescriptions[?TargetHealth.State==`healthy`] | length(@)' \
    --output text)

echo "🏥 $INACTIVE_TG target group health: $HEALTHY_COUNT/$TOTAL_COUNT healthy"

if [ $HEALTHY_COUNT -ne $TOTAL_COUNT ]; then
    echo "⚠️  Not all instances are healthy in $INACTIVE_TG target group"
    echo "💡 You may need to wait longer or check the instances manually"
fi

echo ""
echo "🎯 Next steps:"
echo "1. Verify the deployment in $INACTIVE_TG target group"
echo "2. Run: ./scripts/switch-blue-green.sh $ENVIRONMENT $INACTIVE_TG"
echo "3. Monitor for any issues"
echo "4. If issues occur, switch back: ./scripts/switch-blue-green.sh $ENVIRONMENT $ACTIVE_TG"