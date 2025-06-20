#!/bin/bash
# Post-deployment validation and monitoring script with Discord notifications

set -e

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/../logs"
VALIDATION_TIMEOUT=300  # 5 minutes
MONITORING_DURATION=600 # 10 minutes

# Create logs directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Logging setup
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
VALIDATION_LOG="${LOG_DIR}/validation-${TIMESTAMP}.log"
MONITORING_LOG="${LOG_DIR}/monitoring-${TIMESTAMP}.log"

# Redirect output to both console and log file
exec > >(tee -a "$VALIDATION_LOG")
exec 2> >(tee -a "$VALIDATION_LOG" >&2)

echo "🚀 Post-deployment validation started at $(date)"
echo "📄 Logs: $VALIDATION_LOG"

# Load Terraform configuration
source "${SCRIPT_DIR}/load-terraform-config.sh"

# Discord notification function
send_discord_notification() {
    local status="$1"
    local message="$2"
    local color="$3"
    local additional_fields="$4"
    
    if [ "${ENABLE_DISCORD}" = "true" ] && [ -n "${DISCORD_WEBHOOK_URL}" ]; then
        local payload=$(cat <<EOF
{
    "embeds": [{
        "title": "🚀 Deployment ${status}",
        "description": "${message}",
        "color": ${color},
        "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
        "fields": [
            {"name": "🏷️ Environment", "value": "${ENVIRONMENT}", "inline": true},
            {"name": "🎯 Target Group", "value": "${ACTIVE_TARGET_GROUP}", "inline": true},
            {"name": "🌎 Region", "value": "${REGION}", "inline": true}${additional_fields}
        ],
        "footer": {"text": "AWS Docker Deployment"}
    }]
}
EOF
        )
        
        echo "📱 Sending Discord notification: ${status}"
        curl -s -H "Content-Type: application/json" \
             -X POST \
             -d "$payload" \
             "${DISCORD_WEBHOOK_URL}" || echo "⚠️ Failed to send Discord notification"
    else
        echo "📱 Discord notifications disabled or webhook not configured"
    fi
}

# Notification wrapper
notify() {
    local status="$1"
    local message="$2"
    local color="$3"
    local additional_fields="$4"
    
    echo "📱 ${status}: ${message}"
    send_discord_notification "$status" "$message" "$color" "$additional_fields"
}

# Get current active target group from ALB listener
get_current_target_group() {
    if [ -n "${HTTPS_LISTENER_ARN}" ]; then
        local current_tg_arn=$(aws elbv2 describe-listeners \
            --listener-arns "${HTTPS_LISTENER_ARN}" \
            --region "${REGION}" \
            --query 'Listeners[0].DefaultActions[0].TargetGroupArn' \
            --output text 2>/dev/null)
        
        if [[ "$current_tg_arn" == *"blue"* ]]; then
            echo "blue"
        elif [[ "$current_tg_arn" == *"green"* ]]; then
            echo "green"
        else
            echo "unknown"
        fi
    else
        echo "unknown"
    fi
}

# Check target group health
check_target_group_health() {
    local target_group_arn="$1"
    local target_group_name="$2"
    
    if [ -z "$target_group_arn" ]; then
        echo "❌ Target group ARN not provided"
        return 1
    fi
    
    echo "🔍 Checking health of ${target_group_name} target group..."
    
    local health_data=$(aws elbv2 describe-target-health \
        --target-group-arn "$target_group_arn" \
        --region "$REGION" \
        --output json 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        echo "❌ Failed to get target group health data"
        return 1
    fi
    
    local total_targets=$(echo "$health_data" | jq '.TargetHealthDescriptions | length')
    local healthy_targets=$(echo "$health_data" | jq '.TargetHealthDescriptions | map(select(.TargetHealth.State == "healthy")) | length')
    local unhealthy_targets=$(echo "$health_data" | jq '.TargetHealthDescriptions | map(select(.TargetHealth.State == "unhealthy")) | length')
    local unused_targets=$(echo "$health_data" | jq '.TargetHealthDescriptions | map(select(.TargetHealth.State == "unused")) | length')
    
    echo "📊 Target Group Health Status:"
    echo "   Total: ${total_targets}, Healthy: ${healthy_targets}, Unhealthy: ${unhealthy_targets}, Unused: ${unused_targets}"
    
    # For active target groups, expect healthy targets
    # For inactive target groups, unused is acceptable
    if [ "$target_group_name" = "active" ]; then
        if [ "$healthy_targets" -eq "$total_targets" ] && [ "$total_targets" -gt 0 ]; then
            echo "✅ All targets in ${target_group_name} target group are healthy"
            return 0
        else
            echo "❌ Not all targets in ${target_group_name} target group are healthy"
            return 1
        fi
    else
        # For inactive target groups, check if targets are registered
        if [ "$total_targets" -gt 0 ]; then
            echo "✅ Targets registered in ${target_group_name} target group"
            return 0
        else
            echo "❌ No targets found in ${target_group_name} target group"
            return 1
        fi
    fi
}

# Test application endpoints
test_application_endpoints() {
    echo "🌐 Testing application endpoints..."
    
    local api_url="https://api.${DOMAIN_NAME}/health"
    local main_url="https://${DOMAIN_NAME}/"
    
    # Test API health endpoint
    echo "🔍 Testing API health endpoint: $api_url"
    if curl -f -s -m 10 "$api_url" > /dev/null 2>&1; then
        echo "✅ API health endpoint responded successfully"
    else
        echo "❌ API health endpoint failed to respond"
        return 1
    fi
    
    # Test main application
    echo "🔍 Testing main application: $main_url"
    if curl -f -s -m 10 "$main_url" > /dev/null 2>&1; then
        echo "✅ Main application responded successfully"
    else
        echo "⚠️ Main application test failed (non-critical)"
        # Don't fail validation for main app issues
    fi
    
    return 0
}

# Automatic rollback function
rollback_deployment() {
    echo "🔄 Triggering automatic rollback..."
    
    local current_tg=$(get_current_target_group)
    local rollback_tg_arn=""
    local rollback_tg_name=""
    
    if [ "$current_tg" = "green" ]; then
        rollback_tg_arn="$BLUE_TG_ARN"
        rollback_tg_name="blue"
    elif [ "$current_tg" = "blue" ]; then
        rollback_tg_arn="$GREEN_TG_ARN"
        rollback_tg_name="green"
    else
        echo "❌ Cannot determine current target group for rollback"
        notify "ROLLBACK_FAILED" "Cannot determine current target group for rollback" "16711680"
        return 1
    fi
    
    echo "🔄 Rolling back from ${current_tg} to ${rollback_tg_name}..."
    
    # Switch ALB listener
    if aws elbv2 modify-listener \
        --listener-arn "$HTTPS_LISTENER_ARN" \
        --default-actions Type=forward,TargetGroupArn="$rollback_tg_arn" \
        --region "$REGION" > /dev/null 2>&1; then
        
        echo "✅ ALB listener switched to ${rollback_tg_name} target group"
        
        # Give it a moment to take effect
        sleep 10
        
        # Test the rollback
        if test_application_endpoints; then
            echo "✅ Rollback successful - application responding"
            notify "ROLLBACK_SUCCESS" "Automatic rollback completed successfully. Traffic restored to ${rollback_tg_name} target group." "65280" \
                   ",{\"name\": \"🔄 Rollback To\", \"value\": \"${rollback_tg_name}\", \"inline\": true}"
            return 0
        else
            echo "❌ Rollback completed but application still not responding"
            notify "ROLLBACK_PARTIAL" "Rollback completed but application still not responding properly" "16776960"
            return 1
        fi
    else
        echo "❌ Failed to switch ALB listener for rollback"
        notify "ROLLBACK_FAILED" "Failed to switch ALB listener during rollback" "16711680"
        return 1
    fi
}

# 5-minute validation phase
validate_deployment() {
    echo "🔍 Starting deployment validation (${VALIDATION_TIMEOUT} seconds)..."
    
    local start_time=$(date +%s)
    local deployment_info=""
    
    # Add deployment details to notification
    if [ -n "$BACKEND_IMAGE" ] && [ -n "$FRONTEND_IMAGE" ]; then
        deployment_info=",{\"name\": \"🖼️ Backend\", \"value\": \"${BACKEND_IMAGE}\", \"inline\": false},{\"name\": \"🎨 Frontend\", \"value\": \"${FRONTEND_IMAGE}\", \"inline\": false}"
    fi
    
    notify "VALIDATION_STARTED" "Deployment validation started. Checking target group health and application endpoints." "3447003" "$deployment_info"
    
    # Determine which target group to validate
    local current_tg=$(get_current_target_group)
    local validation_tg_arn=""
    
    if [ "$current_tg" = "blue" ]; then
        validation_tg_arn="$BLUE_TG_ARN"
    elif [ "$current_tg" = "green" ]; then
        validation_tg_arn="$GREEN_TG_ARN"
    else
        echo "❌ Cannot determine current target group"
        notify "VALIDATION_FAILED" "Cannot determine current target group for validation" "16711680"
        return 1
    fi
    
    echo "🎯 Validating ${current_tg} target group..."
    
    # Wait for targets to stabilize
    echo "⏳ Waiting 60 seconds for targets to stabilize..."
    sleep 60
    
    # Validation loop
    local attempts=0
    local max_attempts=5
    
    while [ $attempts -lt $max_attempts ]; do
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        if [ $elapsed -gt $VALIDATION_TIMEOUT ]; then
            echo "⏰ Validation timeout reached (${VALIDATION_TIMEOUT} seconds)"
            break
        fi
        
        echo "🔍 Validation attempt $((attempts + 1))/${max_attempts} (${elapsed}s elapsed)"
        
        # Check target group health
        if check_target_group_health "$validation_tg_arn" "active"; then
            # Test application endpoints
            if test_application_endpoints; then
                local duration=$(($(date +%s) - start_time))
                echo "✅ Validation passed after ${duration} seconds"
                notify "VALIDATION_SUCCESS" "Validation passed! All targets healthy and application responding." "65280" \
                       ",{\"name\": \"⏱️ Duration\", \"value\": \"${duration}s\", \"inline\": true},{\"name\": \"🎯 Validated\", \"value\": \"${current_tg}\", \"inline\": true}"
                return 0
            fi
        fi
        
        attempts=$((attempts + 1))
        if [ $attempts -lt $max_attempts ]; then
            echo "⏳ Waiting 30 seconds before next attempt..."
            sleep 30
        fi
    done
    
    local duration=$(($(date +%s) - start_time))
    echo "❌ Validation failed after ${duration} seconds"
    notify "VALIDATION_FAILED" "Validation failed! Health checks or application tests failed after ${duration}s." "16711680" \
           ",{\"name\": \"⏱️ Duration\", \"value\": \"${duration}s\", \"inline\": true},{\"name\": \"🎯 Failed Target\", \"value\": \"${current_tg}\", \"inline\": true}"
    return 1
}

# 10-minute extended monitoring
monitor_deployment() {
    echo "📊 Starting extended monitoring (${MONITORING_DURATION} seconds)..."
    
    # Redirect monitoring output to separate log file
    exec > >(tee -a "$MONITORING_LOG")
    exec 2> >(tee -a "$MONITORING_LOG" >&2)
    
    notify "MONITORING_STARTED" "Extended monitoring started. Will monitor for performance issues over the next 10 minutes." "3447003"
    
    local start_time=$(date +%s)
    local check_interval=60  # Check every minute
    local checks=$((MONITORING_DURATION / check_interval))
    local failed_checks=0
    
    for i in $(seq 1 $checks); do
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        echo "📊 Monitoring check ${i}/${checks} (${elapsed}s elapsed)"
        
        # Get current target group
        local current_tg=$(get_current_target_group)
        local monitor_tg_arn=""
        
        if [ "$current_tg" = "blue" ]; then
            monitor_tg_arn="$BLUE_TG_ARN"
        elif [ "$current_tg" = "green" ]; then
            monitor_tg_arn="$GREEN_TG_ARN"
        else
            echo "⚠️ Cannot determine current target group for monitoring"
            failed_checks=$((failed_checks + 1))
            continue
        fi
        
        # Check target health
        if ! check_target_group_health "$monitor_tg_arn" "active" > /dev/null 2>&1; then
            echo "⚠️ Health check failed during monitoring"
            failed_checks=$((failed_checks + 1))
            
            # Alert on repeated failures
            if [ $failed_checks -ge 2 ]; then
                notify "MONITORING_ALERT" "Performance degradation detected! ${failed_checks} consecutive health check failures." "16776960" \
                       ",{\"name\": \"⚠️ Failed Checks\", \"value\": \"${failed_checks}/${i}\", \"inline\": true}"
            fi
        else
            # Reset failed counter on success
            if [ $failed_checks -gt 0 ]; then
                echo "✅ Health checks recovered"
                failed_checks=0
            fi
        fi
        
        # Sleep until next check
        if [ $i -lt $checks ]; then
            sleep $check_interval
        fi
    done
    
    local total_duration=$(($(date +%s) - start_time))
    
    if [ $failed_checks -gt 0 ]; then
        echo "⚠️ Monitoring completed with ${failed_checks} issues detected"
        notify "MONITORING_COMPLETED_ISSUES" "Extended monitoring completed with ${failed_checks} issues detected over ${total_duration}s." "16776960" \
               ",{\"name\": \"⏱️ Duration\", \"value\": \"${total_duration}s\", \"inline\": true},{\"name\": \"⚠️ Issues\", \"value\": \"${failed_checks}\", \"inline\": true}"
    else
        echo "✅ Monitoring completed successfully with no issues"
        notify "MONITORING_COMPLETED" "Extended monitoring completed successfully! No issues detected over ${total_duration}s." "65280" \
               ",{\"name\": \"⏱️ Duration\", \"value\": \"${total_duration}s\", \"inline\": true},{\"name\": \"✅ Status\", \"value\": \"Stable\", \"inline\": true}"
    fi
}

# Main execution
main() {
    echo "🚀 Post-deployment validation started at $(date)"
    echo "📋 Configuration loaded:"
    echo "   Environment: ${ENVIRONMENT}"
    echo "   Region: ${REGION}"
    echo "   Active Target Group: ${ACTIVE_TARGET_GROUP}"
    echo "   Discord Notifications: ${ENABLE_DISCORD}"
    echo "   Domain: ${DOMAIN_NAME}"
    
    # Validate configuration
    if [ -z "$HTTPS_LISTENER_ARN" ] || [ -z "$BLUE_TG_ARN" ] || [ -z "$GREEN_TG_ARN" ]; then
        echo "❌ Missing required configuration. Cannot proceed with validation."
        notify "VALIDATION_ERROR" "Missing required ALB configuration. Check Terraform outputs." "16711680"
        exit 1
    fi
    
    # Start validation
    if validate_deployment; then
        echo "✅ Validation passed - starting extended monitoring"
        
        # Start monitoring in background
        monitor_deployment &
        local monitor_pid=$!
        
        echo "📊 Extended monitoring started in background (PID: $monitor_pid)"
        echo "📄 Monitoring logs: $MONITORING_LOG"
        
        # Create PID file for tracking
        echo "$monitor_pid" > "${LOG_DIR}/monitoring.pid"
        
        echo "🎉 Validation completed successfully at $(date)"
        exit 0
    else
        echo "❌ Validation failed - triggering rollback"
        
        if rollback_deployment; then
            echo "✅ Rollback completed successfully"
            exit 2  # Exit code 2 indicates successful rollback
        else
            echo "❌ Rollback failed - manual intervention required"
            exit 1  # Exit code 1 indicates validation and rollback both failed
        fi
    fi
}

# Handle script interruption
trap 'echo "⚠️ Script interrupted"; notify "VALIDATION_INTERRUPTED" "Validation script was interrupted" "16776960"; exit 130' INT TERM

# Execute main function
main "$@"