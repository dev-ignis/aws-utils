# SQS White Label Examples

This document provides comprehensive examples for deploying the SQS module in various configurations, following our white label approach for maximum flexibility.

## Overview

The SQS module provides:
- **FIFO queues** for ordered message processing
- **Dead letter queues** for error handling
- **CloudWatch monitoring** with customizable alarms
- **IAM roles** for secure API and worker access
- **S3 integration** for storing processed results
- **Multi-tenant support** for enterprise deployments

## Basic Usage Examples

### 1. API Processing (MHT/Amygdalas Use Case)

**File**: `terraform.tfvars`
```hcl
# Basic Configuration
instance_name = "mht-api"
environment   = "production"
sqs_use_case  = "api-processing"

# Standard queues for API processing
sqs_queue_configurations = {
  feedback = {
    fifo_queue                  = true
    content_based_deduplication = false
    description                 = "User feedback processing queue"
    message_retention_seconds   = 1209600    # 14 days
    visibility_timeout_seconds  = 300        # 5 minutes
    max_message_size           = 262144      # 256 KB
    delay_seconds              = 0
    receive_wait_time_seconds  = 20          # Long polling
    enable_dlq                 = true
    max_receive_count          = 3
    alarm_max_depth            = 100
  }
  emails = {
    fifo_queue                  = true
    content_based_deduplication = false
    description                 = "Email campaign processing queue"
    message_retention_seconds   = 1209600    # 14 days
    visibility_timeout_seconds  = 600        # 10 minutes (email processing)
    max_message_size           = 262144      # 256 KB
    delay_seconds              = 0
    receive_wait_time_seconds  = 20
    enable_dlq                 = true
    max_receive_count          = 3
    alarm_max_depth            = 500
  }
  analytics = {
    fifo_queue                  = true
    content_based_deduplication = true       # Dedup analytics events
    description                 = "Analytics events processing queue"
    message_retention_seconds   = 604800     # 7 days (shorter for analytics)
    visibility_timeout_seconds  = 120        # 2 minutes (fast processing)
    max_message_size           = 262144      # 256 KB
    delay_seconds              = 0
    receive_wait_time_seconds  = 20
    enable_dlq                 = true
    max_receive_count          = 3
    alarm_max_depth            = 1000
  }
  testflight = {
    fifo_queue                  = true
    content_based_deduplication = false
    description                 = "TestFlight invitation processing queue"
    message_retention_seconds   = 1209600    # 14 days
    visibility_timeout_seconds  = 300        # 5 minutes
    max_message_size           = 262144      # 256 KB
    delay_seconds              = 0
    receive_wait_time_seconds  = 20
    enable_dlq                 = true
    max_receive_count          = 3
    alarm_max_depth            = 50
  }
}

# Enable all features
enable_sqs_encryption         = true
enable_sqs_s3_integration    = true
enable_sqs_cloudwatch_alarms = true
```

**Generated Resources**:
- Queue names: `mht-api-api-processing-feedback.fifo`, `mht-api-api-processing-emails.fifo`, etc.
- IAM roles: `mht-api-api-processing-api-service-role`, `mht-api-api-processing-worker-service-role`
- CloudWatch alarms: `mht-api-api-processing-feedback-depth-alarm`, etc.

### 2. Data Pipeline Processing

**File**: `terraform.tfvars`
```hcl
# Data Pipeline Configuration
instance_name = "data-platform"
environment   = "production"
sqs_use_case  = "data-pipeline"

# Custom queues for data processing
sqs_queue_configurations = {
  ingestion = {
    fifo_queue                  = false       # Standard queue for high throughput
    content_based_deduplication = false
    description                 = "Data ingestion processing queue"
    message_retention_seconds   = 604800      # 7 days
    visibility_timeout_seconds  = 180         # 3 minutes
    max_message_size           = 262144       # 256 KB
    delay_seconds              = 0
    receive_wait_time_seconds  = 20
    enable_dlq                 = true
    max_receive_count          = 5            # More retries for data
    alarm_max_depth            = 2000
  }
  transformation = {
    fifo_queue                  = true        # FIFO for ordered processing
    content_based_deduplication = true
    description                 = "Data transformation processing queue"
    message_retention_seconds   = 604800      # 7 days
    visibility_timeout_seconds  = 900         # 15 minutes
    max_message_size           = 262144       # 256 KB
    delay_seconds              = 0
    receive_wait_time_seconds  = 20
    enable_dlq                 = true
    max_receive_count          = 3
    alarm_max_depth            = 500
  }
  export = {
    fifo_queue                  = true
    content_based_deduplication = false
    description                 = "Data export processing queue"
    message_retention_seconds   = 1209600     # 14 days
    visibility_timeout_seconds  = 600         # 10 minutes
    max_message_size           = 262144       # 256 KB
    delay_seconds              = 0
    receive_wait_time_seconds  = 20
    enable_dlq                 = true
    max_receive_count          = 3
    alarm_max_depth            = 200
  }
}

# Data pipeline specific settings
enable_sqs_s3_integration    = true          # Essential for data pipeline
sqs_cost_center             = "data-platform"
sqs_project_code           = "dp-2025"
```

### 3. Event Streaming Platform

**File**: `terraform.tfvars`
```hcl
# Event Streaming Configuration
instance_name = "event-hub"
environment   = "production"
sqs_use_case  = "event-streaming"

# High-throughput event processing
sqs_queue_configurations = {
  events = {
    fifo_queue                  = false       # Standard for high throughput
    content_based_deduplication = false
    description                 = "Real-time event processing queue"
    message_retention_seconds   = 345600      # 4 days (shorter retention)
    visibility_timeout_seconds  = 60          # 1 minute (fast processing)
    max_message_size           = 262144       # 256 KB
    delay_seconds              = 0
    receive_wait_time_seconds  = 20
    enable_dlq                 = true
    max_receive_count          = 2            # Fewer retries for real-time
    alarm_max_depth            = 5000         # High threshold
  }
  notifications = {
    fifo_queue                  = true        # FIFO for user notifications
    content_based_deduplication = false
    description                 = "User notification processing queue"
    message_retention_seconds   = 604800      # 7 days
    visibility_timeout_seconds  = 300         # 5 minutes
    max_message_size           = 262144       # 256 KB
    delay_seconds              = 0
    receive_wait_time_seconds  = 20
    enable_dlq                 = true
    max_receive_count          = 3
    alarm_max_depth            = 1000
  }
}

# Streaming optimizations
enable_sqs_encryption = false                # Optional: disable for performance
sqs_log_retention_days = 7                  # Shorter log retention
```

### 4. Multi-tenant Enterprise Deployment

**File**: `terraform.tfvars`
```hcl
# Multi-tenant Configuration
instance_name = "enterprise-platform"
environment   = "production"
sqs_use_case  = "multi-tenant-api"

# Enable multi-tenant features
enable_sqs_multi_tenant = true
sqs_tenant_configurations = {
  "client-alpha" = {
    queue_name_prefix = "alpha"
    custom_tags = {
      Client = "Alpha Corp"
      Tier   = "Enterprise"
      SLA    = "Premium"
    }
  }
  "client-beta" = {
    queue_name_prefix = "beta"
    custom_tags = {
      Client = "Beta Inc"
      Tier   = "Professional"
      SLA    = "Standard"
    }
  }
}

# Standard queue configuration (applied per tenant)
sqs_queue_configurations = {
  processing = {
    fifo_queue                  = true
    content_based_deduplication = false
    description                 = "Client processing queue"
    message_retention_seconds   = 1209600     # 14 days
    visibility_timeout_seconds  = 300         # 5 minutes
    max_message_size           = 262144       # 256 KB
    delay_seconds              = 0
    receive_wait_time_seconds  = 20
    enable_dlq                 = true
    max_receive_count          = 3
    alarm_max_depth            = 200          # Per-tenant threshold
  }
}

# Enterprise features
enable_sqs_cost_allocation_tags = true
sqs_cost_center                = "enterprise-ops"
sqs_project_code              = "ent-2025"
```

### 5. Staging Environment

**File**: `terraform.tfvars`
```hcl
# Staging Configuration
instance_name = "mht-api"
environment   = "staging"                    # Triggers environment overrides
sqs_use_case  = "api-processing"

# Environment overrides for staging
sqs_environment_overrides = {
  staging = {
    message_retention_seconds  = 604800       # 7 days (shorter)
    visibility_timeout_seconds = 60           # 1 minute (faster retry)
    max_receive_count         = 2             # Fewer retries
    alarm_max_depth          = 50            # Lower thresholds
  }
}

# Use default queue configurations (will be overridden by environment settings)
# Reduced monitoring for staging
enable_sqs_cloudwatch_alarms   = true         # Keep monitoring
enable_sqs_operations_logging  = false        # Reduce logging costs
sqs_log_retention_days        = 7            # Shorter retention
```

### 6. Development Environment

**File**: `terraform.tfvars`
```hcl
# Development Configuration
instance_name = "dev-playground"
environment   = "development"
sqs_use_case  = "development"

# Minimal configuration for development
sqs_queue_configurations = {
  test = {
    fifo_queue                  = true
    content_based_deduplication = false
    description                 = "Development test queue"
    message_retention_seconds   = 86400       # 1 day only
    visibility_timeout_seconds  = 30          # 30 seconds
    max_message_size           = 262144       # 256 KB
    delay_seconds              = 0
    receive_wait_time_seconds  = 5            # Shorter polling
    enable_dlq                 = false        # No DLQ for dev
    max_receive_count          = 1
    alarm_max_depth            = 10
  }
}

# Minimal features for development
enable_sqs_encryption         = false        # Simplify development
enable_sqs_cloudwatch_alarms  = false        # Reduce noise
enable_sqs_operations_logging = false        # Minimal logging
create_sqs_instance_profiles  = false        # Not needed for dev
```

## Environment-Specific Configurations

### Production Settings
```hcl
environment = "production"
enable_sqs_encryption         = true         # Always encrypt in production
enable_sqs_cloudwatch_alarms  = true         # Full monitoring
enable_sqs_operations_logging = true         # Complete audit trail
sqs_log_retention_days       = 30           # Extended retention
sqs_cloudwatch_alarm_actions = [             # Alert endpoints
  "arn:aws:sns:us-west-2:123456789012:production-alerts"
]
```

### Staging Settings
```hcl
environment = "staging"
enable_sqs_encryption         = true         # Match production
enable_sqs_cloudwatch_alarms  = true         # Test monitoring
enable_sqs_operations_logging = false        # Reduce costs
sqs_log_retention_days       = 7            # Shorter retention
# No alarm actions for staging
```

### Development Settings
```hcl
environment = "development"
enable_sqs_encryption         = false        # Simplify development
enable_sqs_cloudwatch_alarms  = false        # Reduce noise
enable_sqs_operations_logging = false        # Minimal logging
sqs_log_retention_days       = 3            # Very short retention
```

## Integration Patterns

### API Integration (Express.js)
```javascript
// SQS Helper Module
const AWS = require('aws-sdk');
const sqs = new AWS.SQS();

class SQSService {
  constructor(queueUrls) {
    this.queues = queueUrls; // From terraform output
  }

  async sendMessage(queueName, payload, options = {}) {
    const params = {
      QueueUrl: this.queues[queueName],
      MessageBody: JSON.stringify(payload),
      ...options
    };

    // Add FIFO parameters if needed
    if (this.queues[queueName].endsWith('.fifo')) {
      params.MessageGroupId = options.messageGroupId || 'default';
      if (options.deduplicationId) {
        params.MessageDeduplicationId = options.deduplicationId;
      }
    }

    return await sqs.sendMessage(params).promise();
  }
}

// Express.js Routes
app.post('/api/feedback', async (req, res) => {
  try {
    await sqsService.sendMessage('feedback', {
      userId: req.user.id,
      feedback: req.body.feedback,
      timestamp: new Date().toISOString(),
      source: 'web-app'
    });
    
    res.json({ status: 'queued', requestId: req.id });
  } catch (error) {
    res.status(500).json({ error: 'Failed to queue feedback' });
  }
});
```

### Worker Implementation (Node.js)
```javascript
// Background Worker
const AWS = require('aws-sdk');
const sqs = new AWS.SQS();
const s3 = new AWS.S3();

class SQSWorker {
  constructor(queueUrl, s3Bucket) {
    this.queueUrl = queueUrl;
    this.s3Bucket = s3Bucket;
  }

  async processMessages() {
    while (true) {
      try {
        const messages = await sqs.receiveMessage({
          QueueUrl: this.queueUrl,
          MaxNumberOfMessages: 10,
          WaitTimeSeconds: 20,
          VisibilityTimeoutSeconds: 300
        }).promise();

        if (messages.Messages) {
          await Promise.all(messages.Messages.map(msg => this.handleMessage(msg)));
        }
      } catch (error) {
        console.error('Error processing messages:', error);
        await new Promise(resolve => setTimeout(resolve, 5000));
      }
    }
  }

  async handleMessage(message) {
    try {
      const payload = JSON.parse(message.Body);
      
      // Process the message
      const result = await this.processPayload(payload);
      
      // Store result in S3
      await this.storeResult(result);
      
      // Delete message from queue
      await sqs.deleteMessage({
        QueueUrl: this.queueUrl,
        ReceiptHandle: message.ReceiptHandle
      }).promise();
      
    } catch (error) {
      console.error('Error handling message:', error);
      // Message will become visible again after timeout
    }
  }

  async storeResult(result) {
    const key = `processed/${new Date().getFullYear()}/${new Date().getMonth() + 1}/${new Date().getDate()}/${Date.now()}.json`;
    
    await s3.putObject({
      Bucket: this.s3Bucket,
      Key: key,
      Body: JSON.stringify(result),
      ContentType: 'application/json'
    }).promise();
  }
}
```

### Python Worker Implementation
```python
import boto3
import json
import time
from datetime import datetime

class SQSWorker:
    def __init__(self, queue_url, s3_bucket):
        self.sqs = boto3.client('sqs')
        self.s3 = boto3.client('s3')
        self.queue_url = queue_url
        self.s3_bucket = s3_bucket

    def process_messages(self):
        while True:
            try:
                response = self.sqs.receive_message(
                    QueueUrl=self.queue_url,
                    MaxNumberOfMessages=10,
                    WaitTimeSeconds=20,
                    VisibilityTimeoutSeconds=300
                )
                
                messages = response.get('Messages', [])
                for message in messages:
                    self.handle_message(message)
                    
            except Exception as e:
                print(f"Error processing messages: {e}")
                time.sleep(5)

    def handle_message(self, message):
        try:
            payload = json.loads(message['Body'])
            
            # Process the message
            result = self.process_payload(payload)
            
            # Store in S3
            self.store_result(result)
            
            # Delete from queue
            self.sqs.delete_message(
                QueueUrl=self.queue_url,
                ReceiptHandle=message['ReceiptHandle']
            )
            
        except Exception as e:
            print(f"Error handling message: {e}")

    def store_result(self, result):
        now = datetime.now()
        key = f"processed/{now.year}/{now.month:02d}/{now.day:02d}/{int(time.time())}.json"
        
        self.s3.put_object(
            Bucket=self.s3_bucket,
            Key=key,
            Body=json.dumps(result),
            ContentType='application/json'
        )
```

## Testing and Validation

### Using the Test Script
```bash
# Test all default queues
./scripts/test-sqs-infrastructure.sh

# Test specific queue with custom message count
./scripts/test-sqs-infrastructure.sh feedback 5

# Test analytics queue
./scripts/test-sqs-infrastructure.sh analytics 10
```

### Manual Testing
```bash
# Get queue URLs from terraform
terraform output sqs_queue_urls

# Send test message
aws sqs send-message \
  --queue-url "https://sqs.us-west-2.amazonaws.com/123456789012/mht-api-api-processing-feedback.fifo" \
  --message-body '{"test": true, "timestamp": "2025-01-01T00:00:00Z"}' \
  --message-group-id "test-group"

# Receive message
aws sqs receive-message \
  --queue-url "https://sqs.us-west-2.amazonaws.com/123456789012/mht-api-api-processing-feedback.fifo" \
  --wait-time-seconds 20
```

## Monitoring and Troubleshooting

### CloudWatch Dashboards
The module automatically configures CloudWatch metrics. Key metrics to monitor:
- `ApproximateNumberOfVisibleMessages` - Queue depth
- `ApproximateAgeOfOldestMessage` - Message processing delay
- `NumberOfMessagesSent` - Throughput
- `NumberOfMessagesReceived` - Processing rate
- `NumberOfMessagesDeleted` - Success rate

### Common Issues

**Messages not being processed:**
1. Check worker service is running
2. Verify IAM permissions
3. Check visibility timeout settings
4. Monitor dead letter queues

**High queue depth:**
1. Scale worker instances
2. Optimize message processing time
3. Check for processing errors
4. Review alarm thresholds

**Cost optimization:**
1. Use long polling (20 seconds)
2. Batch message operations
3. Right-size message retention
4. Monitor DLQ usage

## Migration Patterns

### From Standard to FIFO Queues
```hcl
# Before (Standard)
sqs_queue_configurations = {
  processing = {
    fifo_queue = false
    # ... other settings
  }
}

# After (FIFO) - Note: requires queue recreation
sqs_queue_configurations = {
  processing = {
    fifo_queue = true
    content_based_deduplication = false
    message_group_id = "default"  # Required for FIFO
    # ... other settings
  }
}
```

### Scaling Configuration
```hcl
# Scale up for production
sqs_queue_configurations = {
  processing = {
    visibility_timeout_seconds = 900      # Increase timeout
    max_receive_count         = 5         # More retries
    alarm_max_depth          = 2000      # Higher threshold
    # ... other settings
  }
}
```

This completes the comprehensive SQS white label examples covering all major use cases and integration patterns.