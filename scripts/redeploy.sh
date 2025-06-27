#!/bin/bash
# Unified redeployment script for frontend and backend
# Usage: ./redeploy.sh <environment> <service>
# Examples:
#   ./redeploy.sh staging be
#   ./redeploy.sh staging fe
#   ./redeploy.sh production be
#   ./redeploy.sh production fe

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

echo "🚀 Starting $SERVICE_NAME redeployment for $ENVIRONMENT environment..."

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
    
    # Copy .env file for both backend and frontend deployments
    # Try different locations for .env file
    ENV_FILE=""
    for path in "../.env" "../../.env" ".env"; do
        if [ -f "$path" ]; then
            ENV_FILE="$path"
            break
        fi
    done
    
    if [ -n "$ENV_FILE" ]; then
        echo "📁 Copying .env file from $ENV_FILE..."
        scp -i ~/.ssh/id_rsa_github "$ENV_FILE" ubuntu@$IP:/home/ubuntu/.env
        ssh -i ~/.ssh/id_rsa_github ubuntu@$IP "chmod 600 /home/ubuntu/.env"
        echo "✅ .env file copied successfully"
    else
        echo "⚠️  No .env file found in any of these locations:"
        echo "    - ../.env (parent of submodule)"
        echo "    - ../../.env (parent of scripts)"  
        echo "    - .env (current directory)"
        echo "💡 Make sure .env exists in the parent directory of this submodule"
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