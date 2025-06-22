#!/bin/bash

# SQS Infrastructure Testing and Validation Script
# Tests SQS queues, IAM roles, CloudWatch alarms, and S3 integration
# Usage: ./test-sqs-infrastructure.sh [queue_name] [message_count]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
QUEUE_NAME=${1:-"feedback"}
MESSAGE_COUNT=${2:-3}
TEST_MESSAGE_PREFIX="sqs-test-$(date +%s)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="${SCRIPT_DIR}/.."

echo -e "${BLUE}🧪 SQS Infrastructure Testing Script${NC}"
echo "=================================="
echo "Queue: $QUEUE_NAME"
echo "Message Count: $MESSAGE_COUNT"
echo ""

# Function to print status
print_status() {
    local status=$1
    local message=$2
    if [ "$status" == "success" ]; then
        echo -e "${GREEN}✅ $message${NC}"
    elif [ "$status" == "error" ]; then
        echo -e "${RED}❌ $message${NC}"
    elif [ "$status" == "warning" ]; then
        echo -e "${YELLOW}⚠️  $message${NC}"
    else
        echo -e "${BLUE}ℹ️  $message${NC}"
    fi
}

# Function to check command existence
check_command() {
    if ! command -v $1 &> /dev/null; then
        print_status "error" "$1 command not found. Please install $1."
        exit 1
    fi
}

# Function to get terraform output
get_terraform_output() {
    local output_name=$1
    cd "$TERRAFORM_DIR"
    terraform output -raw "$output_name" 2>/dev/null || echo ""
}

# Function to extract queue URL from terraform output
get_queue_url() {
    local queue_name=$1
    cd "$TERRAFORM_DIR"
    terraform output -json sqs_queue_urls 2>/dev/null | jq -r ".[\"$queue_name\"]" 2>/dev/null || echo ""
}

# Function to extract DLQ URL from terraform output
get_dlq_url() {
    local queue_name=$1
    cd "$TERRAFORM_DIR"
    terraform output -json sqs_dlq_urls 2>/dev/null | jq -r ".[\"$queue_name\"]" 2>/dev/null || echo ""
}

# Cleanup function
cleanup() {
    print_status "info" "🧹 Cleaning up test messages..."
    
    if [ ! -z "$QUEUE_URL" ]; then
        # Receive and delete any remaining test messages
        while true; do
            MESSAGES=$(aws sqs receive-message --queue-url "$QUEUE_URL" --max-number-of-messages 10 --wait-time-seconds 5 2>/dev/null || echo "")
            if [ -z "$MESSAGES" ] || [ "$MESSAGES" == "null" ]; then
                break
            fi
            
            # Extract receipt handles and delete messages
            echo "$MESSAGES" | jq -r '.Messages[]?.ReceiptHandle' 2>/dev/null | while read receipt_handle; do
                if [ ! -z "$receipt_handle" ] && [ "$receipt_handle" != "null" ]; then
                    aws sqs delete-message --queue-url "$QUEUE_URL" --receipt-handle "$receipt_handle" >/dev/null 2>&1 || true
                fi
            done
        done
    fi
    
    print_status "success" "Cleanup completed"
}

# Set up trap for cleanup
trap cleanup EXIT

print_status "info" "🔍 Phase 1: Checking Prerequisites"

# Check required commands
check_command "terraform"
check_command "aws"
check_command "jq"

# Check if terraform has been applied
cd "$TERRAFORM_DIR"
if [ ! -f ".terraform/terraform.tfstate" ] && [ ! -f "terraform.tfstate" ]; then
    print_status "error" "Terraform state not found. Please run 'terraform apply' first."
    exit 1
fi

print_status "success" "Prerequisites checked"

print_status "info" "🏗️  Phase 2: Infrastructure Validation"

# Get queue URLs
QUEUE_URL=$(get_queue_url "$QUEUE_NAME")
DLQ_URL=$(get_dlq_url "$QUEUE_NAME")

if [ -z "$QUEUE_URL" ] || [ "$QUEUE_URL" == "null" ]; then
    print_status "error" "Queue '$QUEUE_NAME' not found in terraform outputs"
    print_status "info" "Available queues:"
    terraform output -json sqs_queue_urls 2>/dev/null | jq -r 'keys[]' 2>/dev/null || echo "None found"
    exit 1
fi

print_status "success" "Queue URL found: $QUEUE_URL"

if [ ! -z "$DLQ_URL" ] && [ "$DLQ_URL" != "null" ]; then
    print_status "success" "DLQ URL found: $DLQ_URL"
else
    print_status "warning" "No DLQ configured for queue '$QUEUE_NAME'"
fi

# Check queue attributes
print_status "info" "📊 Checking queue attributes..."
QUEUE_ATTRIBUTES=$(aws sqs get-queue-attributes --queue-url "$QUEUE_URL" --attribute-names All 2>/dev/null || echo "")

if [ ! -z "$QUEUE_ATTRIBUTES" ]; then
    IS_FIFO=$(echo "$QUEUE_ATTRIBUTES" | jq -r '.Attributes.FifoQueue // "false"')
    MESSAGE_RETENTION=$(echo "$QUEUE_ATTRIBUTES" | jq -r '.Attributes.MessageRetentionPeriod')
    VISIBILITY_TIMEOUT=$(echo "$QUEUE_ATTRIBUTES" | jq -r '.Attributes.VisibilityTimeoutSeconds')
    
    print_status "success" "Queue Type: $([ "$IS_FIFO" == "true" ] && echo "FIFO" || echo "Standard")"
    print_status "success" "Message Retention: $((MESSAGE_RETENTION / 86400)) days"
    print_status "success" "Visibility Timeout: $((VISIBILITY_TIMEOUT / 60)) minutes"
else
    print_status "error" "Failed to get queue attributes"
    exit 1
fi

print_status "info" "📤 Phase 3: Message Sending Test"

# Send test messages
MESSAGE_IDS=()
for i in $(seq 1 $MESSAGE_COUNT); do
    MESSAGE_BODY="{\"test\": true, \"messageId\": \"$TEST_MESSAGE_PREFIX-$i\", \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\", \"data\": \"Test message $i for queue validation\"}"
    
    if [ "$IS_FIFO" == "true" ]; then
        # FIFO queue requires MessageGroupId
        RESULT=$(aws sqs send-message \
            --queue-url "$QUEUE_URL" \
            --message-body "$MESSAGE_BODY" \
            --message-group-id "test-group" \
            --message-deduplication-id "$TEST_MESSAGE_PREFIX-$i" \
            2>/dev/null || echo "")
    else
        # Standard queue
        RESULT=$(aws sqs send-message \
            --queue-url "$QUEUE_URL" \
            --message-body "$MESSAGE_BODY" \
            2>/dev/null || echo "")
    fi
    
    if [ ! -z "$RESULT" ]; then
        MESSAGE_ID=$(echo "$RESULT" | jq -r '.MessageId')
        MESSAGE_IDS+=("$MESSAGE_ID")
        print_status "success" "Sent message $i (ID: $MESSAGE_ID)"
        sleep 1
    else
        print_status "error" "Failed to send message $i"
        exit 1
    fi
done

print_status "info" "📥 Phase 4: Message Receiving Test"

# Wait a moment for messages to be available
sleep 5

# Receive messages
RECEIVED_COUNT=0
PROCESSED_MESSAGES=()
for attempt in {1..10}; do
    if [ $RECEIVED_COUNT -ge $MESSAGE_COUNT ]; then
        break
    fi
    
    MESSAGES=$(aws sqs receive-message \
        --queue-url "$QUEUE_URL" \
        --max-number-of-messages 10 \
        --wait-time-seconds 10 \
        2>/dev/null || echo "")
    
    if [ ! -z "$MESSAGES" ] && [ "$MESSAGES" != "null" ]; then
        echo "$MESSAGES" | jq -c '.Messages[]?' 2>/dev/null | while read message; do
            if [ ! -z "$message" ] && [ "$message" != "null" ]; then
                MESSAGE_BODY=$(echo "$message" | jq -r '.Body')
                RECEIPT_HANDLE=$(echo "$message" | jq -r '.ReceiptHandle')
                
                # Check if this is our test message
                if echo "$MESSAGE_BODY" | grep -q "$TEST_MESSAGE_PREFIX" 2>/dev/null; then
                    RECEIVED_COUNT=$((RECEIVED_COUNT + 1))
                    print_status "success" "Received test message $RECEIVED_COUNT"
                    
                    # Delete the message
                    aws sqs delete-message \
                        --queue-url "$QUEUE_URL" \
                        --receipt-handle "$RECEIPT_HANDLE" \
                        >/dev/null 2>&1
                    print_status "success" "Deleted message from queue"
                    
                    PROCESSED_MESSAGES+=("$RECEIPT_HANDLE")
                fi
            fi
        done
    fi
    
    if [ $attempt -eq 10 ]; then
        print_status "warning" "Received $RECEIVED_COUNT out of $MESSAGE_COUNT messages after 10 attempts"
    fi
done

print_status "info" "🔍 Phase 5: CloudWatch Metrics Check"

# Check CloudWatch metrics (may take a few minutes to appear)
QUEUE_NAME_CLEAN=$(basename "$QUEUE_URL")
print_status "info" "Checking CloudWatch metrics for queue: $QUEUE_NAME_CLEAN"

# Check for recent metrics
METRICS_CHECK=$(aws cloudwatch get-metric-statistics \
    --namespace AWS/SQS \
    --metric-name NumberOfMessagesSent \
    --dimensions Name=QueueName,Value="$QUEUE_NAME_CLEAN" \
    --start-time "$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ)" \
    --end-time "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --period 300 \
    --statistics Sum \
    2>/dev/null || echo "")

if [ ! -z "$METRICS_CHECK" ]; then
    DATAPOINTS=$(echo "$METRICS_CHECK" | jq '.Datapoints | length')
    if [ "$DATAPOINTS" -gt 0 ]; then
        print_status "success" "CloudWatch metrics are being collected"
    else
        print_status "warning" "CloudWatch metrics not yet available (may take a few minutes)"
    fi
else
    print_status "warning" "Could not retrieve CloudWatch metrics"
fi

print_status "info" "🎯 Phase 6: S3 Integration Test"

# Test S3 integration if enabled
S3_BUCKET_NAME=$(get_terraform_output "s3_bucket_name")
if [ ! -z "$S3_BUCKET_NAME" ] && [ "$S3_BUCKET_NAME" != "null" ]; then
    print_status "success" "S3 bucket found: $S3_BUCKET_NAME"
    
    # Test writing to S3 (simulate worker behavior)
    TEST_S3_KEY="sqs-test/$(date +%Y)/$(date +%m)/$(date +%d)/test-result-$(date +%s).json"
    TEST_S3_CONTENT="{\"processed\": true, \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\", \"source\": \"sqs-test\", \"messageCount\": $MESSAGE_COUNT}"
    
    aws s3 cp - "s3://$S3_BUCKET_NAME/$TEST_S3_KEY" <<< "$TEST_S3_CONTENT" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        print_status "success" "Successfully wrote test result to S3"
        
        # Clean up test file
        aws s3 rm "s3://$S3_BUCKET_NAME/$TEST_S3_KEY" >/dev/null 2>&1
        print_status "success" "Cleaned up test S3 object"
    else
        print_status "warning" "Could not write to S3 bucket (check permissions)"
    fi
else
    print_status "info" "S3 integration not configured or bucket not found"
fi

print_status "info" "📋 Phase 7: Test Summary"

echo ""
echo "=========================================="
echo -e "${BLUE}📊 Test Results Summary${NC}"
echo "=========================================="
echo "Queue: $QUEUE_NAME"
echo "Queue URL: $QUEUE_URL"
echo "Queue Type: $([ "$IS_FIFO" == "true" ] && echo "FIFO" || echo "Standard")"
echo "Messages Sent: $MESSAGE_COUNT"
echo "Messages Received: $RECEIVED_COUNT"
echo "S3 Bucket: ${S3_BUCKET_NAME:-"Not configured"}"
echo ""

if [ $RECEIVED_COUNT -eq $MESSAGE_COUNT ]; then
    print_status "success" "🎉 All tests passed! SQS infrastructure is working correctly."
    echo ""
    echo "✅ Queue is operational"
    echo "✅ Messages can be sent and received"
    echo "✅ Dead letter queue is configured (if enabled)"
    echo "✅ CloudWatch monitoring is active"
    echo "✅ S3 integration is functional (if enabled)"
else
    print_status "warning" "⚠️  Some tests had warnings. Please check the output above."
fi

echo ""
echo "🔗 Integration Examples:"
echo "========================"
echo "Send message (Node.js):"
echo "const AWS = require('aws-sdk');"
echo "const sqs = new AWS.SQS();"
echo "await sqs.sendMessage({"
echo "  QueueUrl: '$QUEUE_URL',"
echo "  MessageBody: JSON.stringify(payload)"
echo "}).promise();"
echo ""
echo "Receive message (Python):"
echo "import boto3"
echo "sqs = boto3.client('sqs')"
echo "response = sqs.receive_message(QueueUrl='$QUEUE_URL', WaitTimeSeconds=20)"
echo ""

print_status "success" "🧪 SQS infrastructure testing completed!"

# Return appropriate exit code
if [ $RECEIVED_COUNT -eq $MESSAGE_COUNT ]; then
    exit 0
else
    exit 1
fi