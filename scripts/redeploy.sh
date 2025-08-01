#!/bin/bash
# Unified redeployment script for frontend and backend
# Usage: ./redeploy.sh <environment> <service> [options]
# Examples:
#   ./redeploy.sh staging be
#   ./redeploy.sh staging fe
#   ./redeploy.sh production be
#   ./redeploy.sh production fe
#   ./redeploy.sh staging fe --auto-switch

set -e

ENVIRONMENT=$1
SERVICE=$2

# Validate parameters
if [ -z "$ENVIRONMENT" ] || [ -z "$SERVICE" ]; then
    echo "❌ Usage: $0 <environment> <service> [options]"
    echo "   Environment: staging | production"
    echo "   Service: be | fe"
    echo "   Options: --auto-switch (for blue-green deployments)"
    echo ""
    echo "Examples:"
    echo "   $0 staging be             # Deploy backend to staging"
    echo "   $0 staging fe             # Deploy frontend to staging"
    echo "   $0 production be          # Deploy backend to production"
    echo "   $0 staging fe --auto-switch  # Deploy with automatic traffic switch"
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

echo "🚀 Starting $SERVICE_NAME redeployment for $ENVIRONMENT environment..."

# Check if blue-green deployment is available
if [ -f "./scripts/blue-green-deploy.sh" ]; then
    # Switch to correct workspace to check blue-green status
    terraform workspace select $ENVIRONMENT 2>/dev/null || true
    
    # Check if blue-green is enabled
    BLUE_GREEN_ENABLED=$(terraform output -json deployment_status 2>/dev/null | jq -r '.blue_green_enabled' 2>/dev/null || echo "false")
    
    if [ "$BLUE_GREEN_ENABLED" = "true" ]; then
        echo "🔵🟢 Blue-green deployment is enabled for $ENVIRONMENT"
        echo "💡 Redirecting to blue-green deployment script..."
        # Pass all arguments after the first two to blue-green-deploy.sh
        shift 2
        exec ./scripts/blue-green-deploy.sh $ENVIRONMENT $SERVICE "$@"
    fi
fi

echo "📦 Using standard rolling deployment..."

# Get instance IPs from Terraform
if [ ! -f "$TFVARS_FILE" ]; then
    echo "❌ Terraform vars file not found: $TFVARS_FILE"
    exit 1
fi

INSTANCE_IPS=($(terraform output -json public_ips 2>/dev/null | jq -r '.[]' 2>/dev/null || echo ""))

if [ ${#INSTANCE_IPS[@]} -eq 0 ]; then
    echo "❌ Could not get instance IPs from Terraform output"
    echo "💡 Make sure you've run 'terraform apply' and instances are running"
    exit 1
fi

echo "📍 Found ${#INSTANCE_IPS[@]} instances: ${INSTANCE_IPS[@]}"

# Note: Script now uses existing .env file on each instance
# Make sure /home/ubuntu/.env exists with all required environment variables

# Function to redeploy service on a single instance
redeploy_service() {
    local IP=$1
    local INSTANCE_NUM=$2
    
    echo "📦 Redeploying $SERVICE_NAME on instance $INSTANCE_NUM ($IP)..."
    
    # Copy environment-specific .env file for both backend and frontend deployments
    # Get the directory where the script was called from
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    CALLING_DIR="$(pwd)"
    
    # Try different locations for .env file based on environment
    ENV_FILE=""
    ENV_PATHS=(
        "$CALLING_DIR/.env.$ENVIRONMENT"  # Where script was called from (primary location)
        "$SCRIPT_DIR/../.env.$ENVIRONMENT" # Parent of scripts directory
        "../.env.$ENVIRONMENT"
        "../../.env.$ENVIRONMENT"
        ".env.$ENVIRONMENT"
    )
    
    for path in "${ENV_PATHS[@]}"; do
        if [ -f "$path" ]; then
            ENV_FILE="$path"
            echo "📁 Found environment file: $ENV_FILE"
            break
        fi
    done
    
    if [ -n "$ENV_FILE" ]; then
        echo "📁 Copying .env file from $ENV_FILE..."
        scp -i ~/.ssh/id_rsa_github "$ENV_FILE" ubuntu@$IP:/home/ubuntu/.env
        ssh -i ~/.ssh/id_rsa_github ubuntu@$IP "chmod 600 /home/ubuntu/.env"
        echo "✅ .env file copied successfully"
    else
        echo "⚠️  No .env.$ENVIRONMENT file found in any of these locations:"
        echo "    - $CALLING_DIR/.env.$ENVIRONMENT (where you ran the script from)"
        echo "    - $SCRIPT_DIR/../.env.$ENVIRONMENT (aws-docker-deployment directory)"
        echo "    - Various relative paths"
        echo "💡 Create .env.$ENVIRONMENT file in the directory where you run the script"
        echo "   Current directory: $CALLING_DIR"
        echo ""
        echo "❌ Deployment cannot proceed without environment-specific configuration"
        exit 1
    fi
    
    ssh -i ~/.ssh/id_rsa_github ubuntu@$IP << EOF
        set -e
        
        $(if [ "$SERVICE" = "be" ]; then
            echo "echo '🔧 Setting up .env file...'"
            echo "if [ -f /home/ubuntu/.env ]; then"
            echo "  echo '✅ Found existing .env file with \$(wc -l < /home/ubuntu/.env) lines'"
            echo "else"
            echo "  echo '⚠️  No .env file found on instance, will need to copy from local'"
            echo "fi"
        fi)
        
        echo "📥 Pulling latest $SERVICE_NAME image..."
        sudo docker pull $IMAGE
        
        echo "🧹 Cleaning up any existing _new and _final containers and port conflicts..."
        sudo docker stop ${CONTAINER}_new || true
        sudo docker rm ${CONTAINER}_new || true
        sudo docker stop ${CONTAINER}_final || true
        sudo docker rm ${CONTAINER}_final || true
        
        # Also clean up any containers using the temp port
        TEMP_PORT_CONTAINERS=\$(sudo docker ps -q --filter publish=$TEMP_PORT)
        if [ -n "\$TEMP_PORT_CONTAINERS" ]; then
            echo "🧹 Stopping containers using port $TEMP_PORT..."
            sudo docker stop \$TEMP_PORT_CONTAINERS || true
            sudo docker rm \$TEMP_PORT_CONTAINERS || true
        fi
        
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
        
        # Clean up any containers using the final port
        FINAL_PORT_CONTAINERS=\$(sudo docker ps -q --filter publish=$PORT)
        if [ -n \"\$FINAL_PORT_CONTAINERS\" ]; then
            echo \"🧹 Stopping containers using port $PORT...\"
            sudo docker stop \$FINAL_PORT_CONTAINERS || true
            sudo docker rm \$FINAL_PORT_CONTAINERS || true
        fi
        
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
        
        echo "🧹 Cleaning up unused Docker resources..."
        sudo docker system prune -f
        
        echo "✅ $SERVICE_NAME deployment complete on instance $INSTANCE_NUM"
EOF
    
    if [ $? -eq 0 ]; then
        echo "✅ Instance $INSTANCE_NUM ($IP) - SUCCESS"
    else
        echo "❌ Instance $INSTANCE_NUM ($IP) - FAILED"
        return 1
    fi
}

# Deploy to all instances sequentially
SUCCESS_COUNT=0
for i in "${!INSTANCE_IPS[@]}"; do
    INSTANCE_NUM=$((i + 1))
    if redeploy_service "${INSTANCE_IPS[$i]}" "$INSTANCE_NUM"; then
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    fi
    echo ""
done

echo "🎉 $SERVICE_NAME redeployment complete!"
echo "✅ Successful deployments: $SUCCESS_COUNT/${#INSTANCE_IPS[@]}"

if [ $SUCCESS_COUNT -eq ${#INSTANCE_IPS[@]} ]; then
    echo "🚀 All instances updated successfully!"
    exit 0
else
    echo "⚠️  Some deployments failed. Check the logs above."
    exit 1
fi