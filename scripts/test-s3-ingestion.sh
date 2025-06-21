!/bin/bash

# S3 Storage Module Test Script - White Label Ready
# This script tests the S3 storage infrastructure with proper partitioning
# Works with any white label S3 configuration (analytics, media, SaaS, etc.)
#
# Usage Examples:
#   # Analytics platform
#   S3_BUCKET_NAME=client-analytics-12345 S3_DATA_PREFIX=analytics/ S3_USE_CASE=analytics ./test-s3-ingestion.sh
#   
#   # Media platform  
#   S3_BUCKET_NAME=media-storage-67890 S3_DATA_PREFIX=uploads/ S3_USE_CASE=media ./test-s3-ingestion.sh
#   
#   # Multi-tenant SaaS
#   S3_BUCKET_NAME=saas-tenant-data-abcde S3_DATA_PREFIX=tenant-data/ S3_USE_CASE=multi-tenant-saas ./test-s3-ingestion.sh

set -e

# Configuration
BUCKET_NAME="${S3_BUCKET_NAME:-}"
REGION="${AWS_REGION:-us-west-2}"
DATA_PREFIX="${S3_DATA_PREFIX:-data/}"      # Configurable for white label
USE_CASE="${S3_USE_CASE:-storage-test}"     # Configurable use case
TEST_DATA_DIR="/tmp/s3-test-data"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        log_error "jq is not installed"
        exit 1
    fi
    
    if [ -z "$BUCKET_NAME" ]; then
        log_error "S3_BUCKET_NAME environment variable is not set"
        log_info "Usage: S3_BUCKET_NAME=your-bucket-name [S3_DATA_PREFIX=data/] [S3_USE_CASE=analytics] $0"
        log_info "Examples:"
        log_info "  S3_BUCKET_NAME=my-analytics-bucket S3_DATA_PREFIX=analytics/ S3_USE_CASE=analytics $0"
        log_info "  S3_BUCKET_NAME=my-media-bucket S3_DATA_PREFIX=uploads/ S3_USE_CASE=media $0"
        exit 1
    fi
    
    # Test AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured properly"
        exit 1
    fi
    
    log_info "Prerequisites check passed"
}

# Create test data
create_test_data() {
    log_info "Creating test data..."
    
    mkdir -p "$TEST_DATA_DIR"
    
    # Get current timestamp for partitioning
    CURRENT_YEAR=$(date +%Y)
    CURRENT_MONTH=$(date +%m)
    CURRENT_DAY=$(date +%d)
    CURRENT_HOUR=$(date +%H)
    TIMESTAMP=$(date +%Y-%m-%d\ %H:%M:%S)
    
    # Create sample JSON data
    cat > "$TEST_DATA_DIR/events.json" << EOF
{"event_id": "evt_001", "timestamp": "$TIMESTAMP", "user_id": "user_123", "event_type": "page_view", "properties": {"page": "/home", "referrer": "google.com"}}
{"event_id": "evt_002", "timestamp": "$TIMESTAMP", "user_id": "user_456", "event_type": "button_click", "properties": {"button": "signup", "page": "/landing"}}
{"event_id": "evt_003", "timestamp": "$TIMESTAMP", "user_id": "user_789", "event_type": "form_submit", "properties": {"form": "contact", "success": "true"}}
EOF
    
    # Create sample CSV data
    cat > "$TEST_DATA_DIR/metrics.csv" << EOF
timestamp,metric_name,value,tags
$TIMESTAMP,cpu_usage,75.5,host=web-01
$TIMESTAMP,memory_usage,82.1,host=web-01
$TIMESTAMP,disk_usage,45.3,host=web-01
EOF
    
    # Create sample processed data (Parquet simulation with JSON)
    cat > "$TEST_DATA_DIR/processed_summary.json" << EOF
{
  "processing_timestamp": "$TIMESTAMP",
  "total_events": 3,
  "event_types": {
    "page_view": 1,
    "button_click": 1,
    "form_submit": 1
  },
  "unique_users": 3,
  "partition_info": {
    "year": $CURRENT_YEAR,
    "month": $CURRENT_MONTH,
    "day": $CURRENT_DAY,
    "hour": $CURRENT_HOUR
  }
}
EOF
    
    log_info "Test data created in $TEST_DATA_DIR"
    
    # Export partition variables for use in upload functions
    export PARTITION_YEAR=$CURRENT_YEAR
    export PARTITION_MONTH=$CURRENT_MONTH
    export PARTITION_DAY=$CURRENT_DAY
    export PARTITION_HOUR=$CURRENT_HOUR
}

# Test bucket access
test_bucket_access() {
    log_info "Testing bucket access..."
    
    if aws s3 ls "s3://$BUCKET_NAME" --region "$REGION" &> /dev/null; then
        log_info "✓ Bucket access confirmed"
    else
        log_error "Cannot access bucket s3://$BUCKET_NAME"
        exit 1
    fi
}

# Upload raw data with proper partitioning
upload_raw_data() {
    log_info "Uploading test data with Athena partitioning..."
    
    PARTITION_PATH="${DATA_PREFIX}year=$PARTITION_YEAR/month=$PARTITION_MONTH/day=$PARTITION_DAY/hour=$PARTITION_HOUR"
    
    # Upload events data
    aws s3 cp "$TEST_DATA_DIR/events.json" \
        "s3://$BUCKET_NAME/$PARTITION_PATH/events_$(date +%Y%m%d_%H%M%S).json" \
        --region "$REGION"
    
    # Upload metrics data
    aws s3 cp "$TEST_DATA_DIR/metrics.csv" \
        "s3://$BUCKET_NAME/$PARTITION_PATH/metrics_$(date +%Y%m%d_%H%M%S).csv" \
        --region "$REGION"
    
    log_info "✓ Test data uploaded to $PARTITION_PATH"
}

# Upload processed data
upload_processed_data() {
    log_info "Uploading processed data..."
    
    PROCESSED_PATH="processed/year=$PARTITION_YEAR/month=$PARTITION_MONTH/day=$PARTITION_DAY/hour=$PARTITION_HOUR"
    
    aws s3 cp "$TEST_DATA_DIR/processed_summary.json" \
        "s3://$BUCKET_NAME/$PROCESSED_PATH/summary_$(date +%Y%m%d_%H%M%S).json" \
        --region "$REGION"
    
    log_info "✓ Processed data uploaded to $PROCESSED_PATH"
}

# Test temporary data upload
upload_temp_data() {
    log_info "Uploading temporary data..."
    
    echo "Temporary staging data - $(date)" > "$TEST_DATA_DIR/temp_file.txt"
    
    aws s3 cp "$TEST_DATA_DIR/temp_file.txt" \
        "s3://$BUCKET_NAME/temp/staging_$(date +%Y%m%d_%H%M%S).txt" \
        --region "$REGION"
    
    log_info "✓ Temporary data uploaded (will be auto-deleted in 7 days)"
}

# Verify uploads
verify_uploads() {
    log_info "Verifying uploads..."
    
    # Check test data
    TEST_COUNT=$(aws s3 ls "s3://$BUCKET_NAME/${DATA_PREFIX}year=$PARTITION_YEAR/month=$PARTITION_MONTH/day=$PARTITION_DAY/hour=$PARTITION_HOUR/" --region "$REGION" | wc -l)
    if [ "$TEST_COUNT" -gt 0 ]; then
        log_info "✓ Test data files found: $TEST_COUNT"
    else
        log_warn "No test data files found"
    fi
    
    # Check processed data
    PROCESSED_COUNT=$(aws s3 ls "s3://$BUCKET_NAME/processed/year=$PARTITION_YEAR/month=$PARTITION_MONTH/day=$PARTITION_DAY/hour=$PARTITION_HOUR/" --region "$REGION" | wc -l)
    if [ "$PROCESSED_COUNT" -gt 0 ]; then
        log_info "✓ Processed data files found: $PROCESSED_COUNT"
    else
        log_warn "No processed data files found"
    fi
    
    # Check temp data
    TEMP_COUNT=$(aws s3 ls "s3://$BUCKET_NAME/temp/" --region "$REGION" | wc -l)
    if [ "$TEMP_COUNT" -gt 0 ]; then
        log_info "✓ Temporary data files found: $TEMP_COUNT"
    else
        log_warn "No temporary data files found"
    fi
}

# Test intelligent tiering status
check_intelligent_tiering() {
    log_info "Checking intelligent tiering configuration..."
    
    if aws s3api get-bucket-intelligent-tiering-configuration \
        --bucket "$BUCKET_NAME" \
        --id "${USE_CASE}-primary-tiering" \
        --region "$REGION" &> /dev/null; then
        log_info "✓ Intelligent tiering is configured"
        
        # Show tiering configuration
        aws s3api get-bucket-intelligent-tiering-configuration \
            --bucket "$BUCKET_NAME" \
            --id "${USE_CASE}-primary-tiering" \
            --region "$REGION" \
            --query 'Configuration.{Status:Status,OptionalFields:OptionalFields,Tierings:Tierings}' \
            --output table
    else
        log_warn "Intelligent tiering configuration not found"
    fi
}

# Test lifecycle policy
check_lifecycle_policy() {
    log_info "Checking lifecycle policy..."
    
    if aws s3api get-bucket-lifecycle-configuration \
        --bucket "$BUCKET_NAME" \
        --region "$REGION" &> /dev/null; then
        log_info "✓ Lifecycle policy is configured"
        
        # Show lifecycle rules
        aws s3api get-bucket-lifecycle-configuration \
            --bucket "$BUCKET_NAME" \
            --region "$REGION" \
            --query 'Rules[*].{ID:ID,Status:Status,Transitions:Transitions[*].{Days:Days,StorageClass:StorageClass}}' \
            --output table
    else
        log_warn "Lifecycle policy not found"
    fi
}

# Generate Athena table creation script
generate_athena_script() {
    log_info "Generating Athena table creation script..."
    
    cat > "$TEST_DATA_DIR/create_athena_table.sql" << EOF
-- Create external table for raw events data
CREATE EXTERNAL TABLE IF NOT EXISTS raw_events (
  event_id string,
  timestamp string,
  user_id string,
  event_type string,
  properties map<string,string>
)
PARTITIONED BY (
  year int,
  month int,
  day int,
  hour int
)
STORED AS JSON
LOCATION 's3://$BUCKET_NAME/${DATA_PREFIX}'
TBLPROPERTIES ('has_encrypted_data'='false');

-- Add partition for current data
ALTER TABLE raw_events ADD IF NOT EXISTS PARTITION (
  year=$PARTITION_YEAR,
  month=$PARTITION_MONTH,
  day=$PARTITION_DAY,
  hour=$PARTITION_HOUR
) LOCATION 's3://$BUCKET_NAME/${DATA_PREFIX}year=$PARTITION_YEAR/month=$PARTITION_MONTH/day=$PARTITION_DAY/hour=$PARTITION_HOUR/';

-- Sample query to test the table
SELECT event_type, COUNT(*) as event_count
FROM raw_events
WHERE year = $PARTITION_YEAR
  AND month = $PARTITION_MONTH
  AND day = $PARTITION_DAY
  AND hour = $PARTITION_HOUR
GROUP BY event_type;
EOF
    
    log_info "✓ Athena script created: $TEST_DATA_DIR/create_athena_table.sql"
}

# Cleanup test data
cleanup() {
    log_info "Cleaning up local test data..."
    rm -rf "$TEST_DATA_DIR"
    log_info "✓ Cleanup completed"
}

# Main execution
main() {
    log_info "Starting S3 Storage Module Test"
    log_info "Bucket: $BUCKET_NAME"
    log_info "Region: $REGION"
    log_info "Data Prefix: $DATA_PREFIX"
    log_info "Use Case: $USE_CASE"
    echo
    
    check_prerequisites
    create_test_data
    test_bucket_access
    upload_raw_data
    upload_processed_data
    upload_temp_data
    verify_uploads
    check_intelligent_tiering
    check_lifecycle_policy
    generate_athena_script
    
    echo
    log_info "🎉 S3 Storage Module Test Completed Successfully!"
    log_info "Next steps:"
    log_info "1. Run the Athena script: $TEST_DATA_DIR/create_athena_table.sql"
    log_info "2. Monitor intelligent tiering transitions in S3 console"
    log_info "3. Check lifecycle policy effects after configured time periods"
    
    # Ask user if they want to keep test data
    read -p "Keep local test data? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        cleanup
    else
        log_info "Test data preserved in: $TEST_DATA_DIR"
    fi
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi