#!/bin/bash
# Load Terraform configuration for external validation script

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "🔧 Loading Terraform configuration..."

# Change to project directory
cd "$PROJECT_DIR"

# Check if Terraform is initialized
if [ ! -d ".terraform" ]; then
    echo "❌ Terraform not initialized. Run 'terraform init' first."
    exit 1
fi

# Check if Terraform state exists
if [ ! -f "terraform.tfstate" ] && [ ! -f ".terraform/terraform.tfstate" ]; then
    echo "❌ No Terraform state found. Run 'terraform apply' first."
    exit 1
fi

echo "📋 Extracting Terraform outputs and variables..."

# Get Terraform outputs
TERRAFORM_OUTPUTS=$(terraform output -json 2>/dev/null || echo '{}')

# Extract ALB configuration
export HTTPS_LISTENER_ARN=$(echo "$TERRAFORM_OUTPUTS" | jq -r '.alb_https_listener_arn.value // empty' 2>/dev/null || echo "")
export BLUE_TG_ARN=$(echo "$TERRAFORM_OUTPUTS" | jq -r '.blue_target_group_arn.value // empty' 2>/dev/null || echo "")
export GREEN_TG_ARN=$(echo "$TERRAFORM_OUTPUTS" | jq -r '.green_target_group_arn.value // empty' 2>/dev/null || echo "")
export MAIN_TG_ARN=$(echo "$TERRAFORM_OUTPUTS" | jq -r '.main_target_group_arn.value // empty' 2>/dev/null || echo "")

# Extract domain and environment info
export DOMAIN_NAME=$(echo "$TERRAFORM_OUTPUTS" | jq -r '.domain_name.value // empty' 2>/dev/null || echo "")
export ENVIRONMENT=$(echo "$TERRAFORM_OUTPUTS" | jq -r '.environment.value // empty' 2>/dev/null || echo "")
export REGION=$(echo "$TERRAFORM_OUTPUTS" | jq -r '.region.value // empty' 2>/dev/null || echo "")

# Load variables from tfvars files (check multiple possible locations)
TFVARS_FILES=(
    "terraform.tfvars"
    "terraform.tfvars.local"
    "terraform.auto.tfvars"
    "terraform.auto.tfvars.local"
)

# Function to extract variable from tfvars files
extract_tfvar() {
    local var_name="$1"
    local value=""
    
    for tfvars_file in "${TFVARS_FILES[@]}"; do
        if [ -f "$tfvars_file" ]; then
            # Extract variable value (handles quoted/unquoted values and inline comments)
            value=$(grep "^${var_name}[[:space:]]*=" "$tfvars_file" 2>/dev/null | head -1 | \
                sed 's/^[^=]*=[[:space:]]*//' | \
                sed 's/[[:space:]]*#.*$//' | \
                sed 's/^"\(.*\)"$/\1/' | \
                sed "s/^'\(.*\)'$/\1/" | \
                sed 's/[[:space:]]*$//')
            if [ -n "$value" ]; then
                break
            fi
        fi
    done
    
    echo "$value"
}

# Extract Discord configuration from tfvars
export DISCORD_WEBHOOK_URL=$(extract_tfvar "discord_webhook_url")
export ENABLE_DISCORD_NOTIFICATIONS=$(extract_tfvar "enable_discord_notifications")
export ACTIVE_TARGET_GROUP=$(extract_tfvar "active_target_group")
export BLUE_GREEN_ENABLED=$(extract_tfvar "blue_green_enabled")
export BACKEND_IMAGE=$(extract_tfvar "backend_image")
export FRONTEND_IMAGE=$(extract_tfvar "front_end_image")
export SKIP_DEPLOYMENT_VALIDATION=$(extract_tfvar "skip_deployment_validation")

# Set defaults if not found
export ENVIRONMENT="${ENVIRONMENT:-$(extract_tfvar "environment")}"
export REGION="${REGION:-$(extract_tfvar "region")}"
export DOMAIN_NAME="${DOMAIN_NAME:-$(extract_tfvar "hosted_zone_name")}"
export ACTIVE_TARGET_GROUP="${ACTIVE_TARGET_GROUP:-blue}"
export BLUE_GREEN_ENABLED="${BLUE_GREEN_ENABLED:-false}"
export ENABLE_DISCORD_NOTIFICATIONS="${ENABLE_DISCORD_NOTIFICATIONS:-false}"
export SKIP_DEPLOYMENT_VALIDATION="${SKIP_DEPLOYMENT_VALIDATION:-false}"

# Convert boolean strings to standardized format
case "${ENABLE_DISCORD_NOTIFICATIONS,,}" in
    true|yes|1) export ENABLE_DISCORD="true" ;;
    *) export ENABLE_DISCORD="false" ;;
esac

case "${BLUE_GREEN_ENABLED,,}" in
    true|yes|1) export BLUE_GREEN_ENABLED="true" ;;
    *) export BLUE_GREEN_ENABLED="false" ;;
esac

case "${SKIP_DEPLOYMENT_VALIDATION,,}" in
    true|yes|1) export SKIP_VALIDATION="true" ;;
    *) export SKIP_VALIDATION="false" ;;
esac

# Validate required configuration
MISSING_CONFIG=()

if [ "$BLUE_GREEN_ENABLED" = "true" ]; then
    [ -z "$HTTPS_LISTENER_ARN" ] && MISSING_CONFIG+=("HTTPS_LISTENER_ARN")
    [ -z "$BLUE_TG_ARN" ] && MISSING_CONFIG+=("BLUE_TG_ARN")
    [ -z "$GREEN_TG_ARN" ] && MISSING_CONFIG+=("GREEN_TG_ARN")
fi

[ -z "$REGION" ] && MISSING_CONFIG+=("REGION")
[ -z "$ENVIRONMENT" ] && MISSING_CONFIG+=("ENVIRONMENT")

if [ "${#MISSING_CONFIG[@]}" -gt 0 ]; then
    echo "❌ Missing required configuration:"
    printf '   - %s\n' "${MISSING_CONFIG[@]}"
    echo ""
    echo "🔍 Available Terraform outputs:"
    terraform output 2>/dev/null || echo "   (none)"
    echo ""
    echo "💡 Make sure you have:"
    echo "   1. Applied Terraform configuration with load balancer enabled"
    echo "   2. Proper outputs defined in outputs.tf"
    echo "   3. Valid terraform.tfvars file with required variables"
    exit 1
fi

# Display loaded configuration
echo "✅ Configuration loaded successfully:"
echo "   Environment: ${ENVIRONMENT}"
echo "   Region: ${REGION}"
echo "   Domain: ${DOMAIN_NAME:-'(not set)'}"
echo "   Blue-Green Enabled: ${BLUE_GREEN_ENABLED}"
echo "   Active Target Group: ${ACTIVE_TARGET_GROUP}"
echo "   Discord Notifications: ${ENABLE_DISCORD}"
echo "   Skip Validation: ${SKIP_VALIDATION}"

if [ "$BLUE_GREEN_ENABLED" = "true" ]; then
    echo "   HTTPS Listener ARN: ${HTTPS_LISTENER_ARN:0:50}..."
    echo "   Blue Target Group ARN: ${BLUE_TG_ARN:0:50}..."
    echo "   Green Target Group ARN: ${GREEN_TG_ARN:0:50}..."
fi

if [ "$ENABLE_DISCORD" = "true" ] && [ -n "$DISCORD_WEBHOOK_URL" ]; then
    echo "   Discord Webhook: ✅ Configured"
else
    echo "   Discord Webhook: ❌ Not configured"
fi

echo ""