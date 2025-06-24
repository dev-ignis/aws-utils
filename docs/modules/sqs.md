# SQS Processing Module Documentation

## Overview

The SQS Processing Module provides a comprehensive, white-label solution for asynchronous message processing using Amazon SQS. It creates FIFO and standard queues with dead letter queues, IAM roles, CloudWatch monitoring, and seamless S3 integration for result storage.

**Key Features:**
- FIFO and Standard queue support with configurable attributes
- Dead Letter Queues (DLQ) for error handling and analysis
- IAM roles for secure API and worker service access
- CloudWatch monitoring with customizable alarms
- S3 integration for storing processed results
- Multi-tenant support for enterprise deployments
- Environment-specific configurations (staging/production)

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   API Service   │    │   SQS Queues    │    │  Worker Service │
│   (Send Msgs)   │───▶│   (FIFO/STD)    │───▶│  (Process Msgs) │
└─────────────────┘    └─────────┬───────┘    └─────────┬───────┘
         │                       │                       │
         │ IAM: api-service-role │ DLQ for failed msgs  │ IAM: worker-service-role
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   CloudWatch    │    │  Dead Letter    │    │   S3 Storage    │
│   Monitoring    │    │     Queues      │    │   Integration   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## Module Interface

### Input Variables

#### Core Configuration
```hcl
variable "instance_name" {
  description = "Name for the deployment instance (e.g., 'mht-api', 'data-platform')"
  type        = string
}

variable "use_case" {
  description = "Use case description (e.g., 'api-processing', 'data-pipeline')"
  type        = string
  default     = "api-processing"
}

variable "environment" {
  description = "Environment name (production, staging, development)"
  type        = string
  default     = "production"
}
```

#### Queue Configuration
```hcl
variable "queue_configurations" {
  description = "Map of SQS queue configurations"
  type = map(object({
    fifo_queue                  = bool
    content_based_deduplication = bool
    description                 = string
    message_retention_seconds   = number
    visibility_timeout_seconds  = number
    max_message_size           = number
    delay_seconds              = number
    receive_wait_time_seconds  = number
    enable_dlq                 = bool
    max_receive_count          = number
    alarm_max_depth            = number
  }))
}
```

#### Security Configuration
```hcl
variable "enable_encryption" {
  description = "Enable SQS encryption using KMS"
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "KMS key ID for encryption (null for AWS managed key)"
  type        = string
  default     = null
}
```

#### IAM Configuration
```hcl
variable "create_api_service_role" {
  description = "Create IAM role for API services to send messages"
  type        = bool
  default     = true
}

variable "create_worker_service_role" {
  description = "Create IAM role for worker services to process messages"
  type        = bool
  default     = true
}

variable "create_instance_profiles" {
  description = "Create EC2 instance profiles for IAM roles"
  type        = bool
  default     = true
}
```

#### Monitoring Configuration
```hcl
variable "enable_cloudwatch_alarms" {
  description = "Enable CloudWatch alarms for queue monitoring"
  type        = bool
  default     = true
}

variable "cloudwatch_alarm_actions" {
  description = "List of ARNs to notify when alarms trigger"
  type        = list(string)
  default     = []
}

variable "enable_operations_logging" {
  description = "Enable CloudWatch logging for SQS operations"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 30
}
```

#### S3 Integration
```hcl
variable "s3_bucket_arn" {
  description = "S3 bucket ARN for worker result storage"
  type        = string
  default     = ""
}

variable "enable_s3_integration" {
  description = "Enable IAM permissions for SQS-S3 integration"
  type        = bool
  default     = true
}
```

### Output Values

#### Queue Information
```hcl
output "queue_urls" {
  description = "URLs of all SQS queues"
  value       = { for k, v in aws_sqs_queue.main_queues : k => v.url }
}

output "queue_arns" {
  description = "ARNs of all SQS queues"
  value       = { for k, v in aws_sqs_queue.main_queues : k => v.arn }
}

output "queue_names" {
  description = "Names of all SQS queues"
  value       = { for k, v in aws_sqs_queue.main_queues : k => v.name }
}

output "dlq_urls" {
  description = "URLs of all dead letter queues"
  value       = { for k, v in aws_sqs_queue.dead_letter_queues : k => v.url }
}
```

#### IAM Resources
```hcl
output "api_service_role_arn" {
  description = "ARN of the API service IAM role"
  value       = var.create_api_service_role ? aws_iam_role.api_service_role[0].arn : null
}

output "worker_service_role_arn" {
  description = "ARN of the worker service IAM role"
  value       = var.create_worker_service_role ? aws_iam_role.worker_service_role[0].arn : null
}

output "api_service_instance_profile_name" {
  description = "Name of the API service instance profile"
  value       = var.create_api_service_role && var.create_instance_profiles ? aws_iam_instance_profile.api_service_profile[0].name : null
}
```

## Usage Examples

### Basic API Processing Setup

```hcl
module "sqs_processing" {
  source = "./modules/sqs"
  
  instance_name = "mht-api"
  use_case     = "api-processing"
  environment  = "production"
  
  queue_configurations = {
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
      visibility_timeout_seconds  = 600        # 10 minutes
      max_message_size           = 262144      # 256 KB
      delay_seconds              = 0
      receive_wait_time_seconds  = 20
      enable_dlq                 = true
      max_receive_count          = 3
      alarm_max_depth            = 500
    }
  }
  
  # Security and Integration
  enable_encryption     = true
  enable_s3_integration = true
  s3_bucket_arn        = module.s3_storage.bucket_arn
  
  # Monitoring
  enable_cloudwatch_alarms = true
  cloudwatch_alarm_actions = ["arn:aws:sns:us-west-2:123456789012:production-alerts"]
  
  tags = {
    Environment = "production"
    Project     = "MHT-API"
  }
}
```

### Data Pipeline Configuration

```hcl
module "data_pipeline_sqs" {
  source = "./modules/sqs"
  
  instance_name = "data-platform"
  use_case     = "data-pipeline"
  environment  = "production"
  
  queue_configurations = {
    ingestion = {
      fifo_queue                  = false       # Standard for high throughput
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
  }
  
  # Cost optimization
  enable_operations_logging = false
  log_retention_days       = 7
}
```

### Staging Environment Configuration

```hcl
module "staging_sqs" {
  source = "./modules/sqs"
  
  instance_name = "mht-api"
  use_case     = "api-processing"
  environment  = "staging"
  
  # Use default queue configurations with environment overrides
  queue_configurations = var.sqs_queue_configurations
  
  # Environment-specific overrides
  environment_specific_overrides = {
    staging = {
      message_retention_seconds  = 604800       # 7 days (shorter)
      visibility_timeout_seconds = 60           # 1 minute (faster retry)
      max_receive_count         = 2             # Fewer retries
      alarm_max_depth          = 50            # Lower thresholds
    }
  }
  
  # Reduced monitoring for staging
  enable_operations_logging = false
  log_retention_days       = 7
}
```

## Integration Patterns

### API Service Integration (Node.js)

```javascript
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

// Express.js usage
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

### Worker Service Integration (Python)

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

## Best Practices

### Queue Configuration

1. **FIFO vs Standard Queues**
   - Use FIFO for ordered processing (feedback, emails)
   - Use Standard for high throughput (analytics, logs)
   - Enable content-based deduplication for analytics events

2. **Message Retention**
   - Production: 14 days for user-facing queues
   - Analytics: 7 days for high-volume event data
   - Staging: 7 days to reduce costs

3. **Visibility Timeout**
   - Set based on processing time: Email (10 min), Analytics (2 min)
   - Account for retries and error handling
   - Use shorter timeouts in staging for faster iteration

### Error Handling

1. **Dead Letter Queues**
   - Always enable DLQs for production queues
   - Set max receive count to 3 for most use cases
   - Monitor DLQ depth with CloudWatch alarms

2. **Retry Strategy**
   - Configure appropriate max receive counts
   - Implement exponential backoff in workers
   - Log failures for debugging

### Monitoring and Alerting

1. **CloudWatch Metrics**
   - Monitor queue depth and message age
   - Set up alarms for queue thresholds
   - Track processing success/failure rates

2. **Cost Optimization**
   - Use long polling (20 seconds) to reduce API calls
   - Batch message operations where possible
   - Right-size message retention periods

### Security

1. **IAM Roles**
   - Use separate roles for API and worker services
   - Follow principle of least privilege
   - Enable cross-account access for multi-tenant setups

2. **Encryption**
   - Enable KMS encryption for sensitive data
   - Use AWS managed keys for simplicity
   - Configure encryption for both main and DLQ

## Testing and Validation

### Using the Test Script

```bash
# Test all queues
./scripts/test-sqs-infrastructure.sh

# Test specific queue
./scripts/test-sqs-infrastructure.sh feedback 5

# Test in different environment
ENV=staging ./scripts/test-sqs-infrastructure.sh
```

### Manual Testing

```bash
# Get queue URLs
terraform output sqs_queue_urls

# Send test message to FIFO queue
aws sqs send-message \
  --queue-url "https://sqs.us-west-2.amazonaws.com/123456789012/mht-api-api-processing-feedback.fifo" \
  --message-body '{"test": true, "timestamp": "2025-01-01T00:00:00Z"}' \
  --message-group-id "test-group"

# Receive messages
aws sqs receive-message \
  --queue-url "https://sqs.us-west-2.amazonaws.com/123456789012/mht-api-api-processing-feedback.fifo" \
  --wait-time-seconds 20
```

## Troubleshooting

### Common Issues

**Messages not being processed:**
1. Check worker service is running and has correct IAM permissions
2. Verify queue visibility timeout settings
3. Monitor dead letter queues for failed messages
4. Check CloudWatch logs for processing errors

**High queue depth:**
1. Scale worker instances or increase processing capacity
2. Optimize message processing time
3. Check for processing bottlenecks or external service delays
4. Review queue alarm thresholds

**Permission errors:**
1. Verify IAM roles have correct policies attached
2. Check if encryption is enabled and KMS permissions are correct
3. Ensure cross-account access is properly configured
4. Validate S3 integration permissions

**Cost concerns:**
1. Monitor message retention settings
2. Use long polling to reduce API calls
3. Batch operations where possible
4. Review DLQ usage and cleanup strategies

### Performance Optimization

1. **Message Processing**
   - Use batch operations for multiple messages
   - Implement efficient polling strategies
   - Parallelize worker processing where appropriate

2. **Cost Management**
   - Right-size visibility timeouts
   - Use appropriate message retention periods
   - Monitor and cleanup DLQs regularly

## Related Documentation

- [SQS White Label Examples](../white-label/sqs-examples.md) - Complete configuration examples
- [S3 Storage Module](s3.md) - Integration with S3 for result storage
- [Zero-Downtime Deployments](../zero-downtime-deployments.md) - Deployment strategies
- [AWS SQS Documentation](https://docs.aws.amazon.com/sqs/) - Official AWS documentation

---

**Module Version:** 1.0  
**Last Updated:** January 2025  
**Compatibility:** Terraform 0.12+, AWS Provider 3.0+