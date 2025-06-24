# SQS Infrastructure Implementation Plan

## Project Overview
**Task**: Provision SQS queue infrastructure for asynchronous processing  
**Integration**: Works with existing S3 data pipeline and MHT API  
**Architecture**: API + SQS + Background Workers + S3 Storage  

## Requirements Analysis

Based on the provided code examples, we need to provision:

### Core Queues (FIFO for ordering):
1. **Feedback Queue**: Process user feedback → Zendesk + Email notifications
2. **Email Queue**: Handle email campaigns with rate limiting
3. **Analytics Queue**: Queue analytics events for S3 storage  
4. **TestFlight Queue**: Manage TestFlight invitations and notifications

### Supporting Infrastructure:
- Dead Letter Queues (DLQ) for error handling
- IAM roles for API access to queues
- CloudWatch monitoring and alarms
- Integration with existing S3 data collection

## Implementation Plan

### Phase 1: Core SQS Infrastructure (High Priority) ✅ **COMPLETED**

#### 1. **SQS Module Creation** ✅ **COMPLETED**
   - ✅ Created white label Terraform module under `modules/sqs/`
   - ✅ Support both FIFO and Standard queue types
   - ✅ Configurable queue attributes (retention, visibility timeout, etc.)
   - ✅ Environment-aware configurations

#### 2. **Queue Definitions** ✅ **COMPLETED**
   ```hcl
   # FIFO Queues for MHT/Amygdalas
   feedback_queue:
     - Name: mht-api-feedback.fifo
     - Message retention: 14 days
     - Visibility timeout: 5 minutes
     - Content-based deduplication: false
     - Dead letter queue: feedback-dlq.fifo
   
   email_queue:
     - Name: mht-api-emails.fifo  
     - Message retention: 14 days
     - Visibility timeout: 10 minutes (email processing)
     - Rate limiting support
     - Dead letter queue: emails-dlq.fifo
   
   analytics_queue:
     - Name: mht-api-analytics.fifo
     - Message retention: 7 days (shorter, for analytics)
     - Visibility timeout: 2 minutes (fast processing)
     - High throughput configuration
     - Dead letter queue: analytics-dlq.fifo
   
   testflight_queue:
     - Name: mht-api-testflight.fifo
     - Message retention: 14 days
     - Visibility timeout: 5 minutes
     - Dead letter queue: testflight-dlq.fifo
   ```

#### 3. **IAM Security Configuration** ✅ **COMPLETED**
   - ✅ API service role: Send messages to all queues
   - ✅ Worker role: Receive and delete messages
   - ✅ S3 integration role: Store processed results
   - ✅ Cross-service permissions with existing S3 bucket

### Phase 2: Error Handling & Monitoring (Medium Priority) ✅ **COMPLETED**

#### 4. **Dead Letter Queue Setup** ✅ **COMPLETED**
   - ✅ DLQ for each main queue
   - ✅ Configure max receive count (3 attempts)
   - ✅ Extended retention for DLQs (14 days)
   - ✅ CloudWatch alarms for DLQ depth

#### 5. **CloudWatch Integration** ✅ **COMPLETED**
   - ✅ Queue depth monitoring
   - ✅ Message age alerts
   - ✅ Processing time metrics
   - ✅ Error rate tracking
   - ✅ Integration with existing Discord notifications

### Phase 3: Integration & Testing (Medium Priority) 

#### 6. **S3 Integration** ✅ **COMPLETED**
   - ✅ Queue outputs store results in existing S3 bucket
   - ✅ Use established partition structure (year/month/day/hour)
   - ✅ Event correlation between SQS and S3 data
   - ✅ Processing status tracking

#### 7. **Testing & Validation** ⏳ **IN PROGRESS**
   - ⏳ SQS message sending/receiving tests (ready to execute)
   - ⏳ Dead letter queue validation (ready to execute)
   - ⏳ Performance benchmarking (ready to execute)
   - ⏳ Error handling verification (ready to execute)

## Deliverables

### Infrastructure Code:
- [x] Terraform SQS module (`modules/sqs/`)
- [x] Integration with main.tf
- [x] Environment-specific tfvars
- [x] IAM roles and policies

### Monitoring & Operations:
- [x] CloudWatch dashboards
- [x] Alerting configuration  
- [x] Testing scripts
- [x] Operational runbooks

### Documentation:
- [x] Module usage guide
- [x] Integration patterns
- [x] White label examples
- [x] Troubleshooting guide

## Technical Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   MHT API       │    │   SQS Queues    │    │   Background    │
│   (Express.js)  │───▶│   (FIFO)        │───▶│   Workers       │
│                 │    │                 │    │   (Node.js)     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Immediate     │    │   Dead Letter   │    │   S3 Storage    │
│   Response      │    │   Queues        │    │   (Existing)    │
│   (200 OK)      │    │   (Error)       │    │   Raw Data      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## Queue Specifications

### Message Flow Examples:

#### Feedback Processing:
```
API POST /feedback → SQS feedback queue → Worker processes:
  1. Create Zendesk ticket
  2. Send confirmation email  
  3. Update database status
  4. Store result in S3
  5. Delete SQS message
```

#### Email Campaign:
```
API POST /campaign → SQS email queue → Worker processes:
  1. Send via SendGrid (rate limited)
  2. Store delivery status in S3
  3. Update campaign metrics
  4. Delete SQS message
```

#### Analytics Events:
```
API analytics events → SQS analytics queue → Worker processes:
  1. Batch events for efficiency
  2. Store in S3 with partition structure
  3. Update real-time dashboards
  4. Delete SQS message
```

## Environment Configuration

### Staging Environment:
- Shorter message retention (7 days)
- Lower visibility timeouts (faster retry)
- Reduced DLQ thresholds
- Test queue names (`mht-api-staging-*`)

### Production Environment:
- Extended retention (14 days)
- Conservative timeouts
- Higher DLQ thresholds
- Production queue names (`mht-api-*`)

## Cost Optimization

### Expected Costs (Beta Volume):
- **FIFO Queues**: ~$0.50 per million requests
- **Message Storage**: ~$0.40 per GB-month
- **Data Transfer**: Minimal (in-region)
- **Total Estimated**: $40-90/month for beta volume

### Optimization Strategies:
- Batch message processing
- Efficient worker polling
- Appropriate message retention
- Dead letter queue monitoring

## Success Metrics

- **API Response Time**: < 200ms (immediate response)
- **Queue Processing**: < 30 seconds average
- **Error Rate**: < 1% failed messages
- **Availability**: 99.9% uptime
- **S3 Integration**: 100% correlation between SQS and S3 events

## White Label Readiness

The SQS module will support:
- **Configurable naming**: `{instance_name}-{use_case}-{queue_type}`
- **Multi-tenant queues**: Separate queues per client/environment
- **Flexible IAM**: Cross-account access for enterprise clients
- **Monitoring integration**: Per-client CloudWatch dashboards
- **Cost allocation**: Tagged resources for billing

## Implementation Status Summary

### ✅ **COMPLETED PHASES**:
- **Phase 1**: Core SQS Infrastructure (High Priority) - 100% Complete
- **Phase 2**: Error Handling & Monitoring (Medium Priority) - 100% Complete  
- **Phase 3**: S3 Integration - 100% Complete

### ⏳ **CURRENT PHASE**: Terraform Deployment & Testing
1. ⏳ **Terraform Init & Plan** - Ready to execute
2. ⏳ **Terraform Apply** - Ready to execute  
3. ⏳ **Infrastructure Testing** - Script ready
4. ⏳ **S3 Integration Validation** - Script ready

### 📋 **NEXT IMMEDIATE STEPS**:
1. Run `terraform init` to initialize backend
2. Run `terraform plan` to validate configuration
3. Run `terraform apply` to provision SQS infrastructure
4. Execute `./scripts/test-sqs-infrastructure.sh` to validate
5. Test S3 integration with worker examples

### 🎯 **READINESS STATUS**: 
**Infrastructure Code: 100% Complete** ✅  
**Documentation: 100% Complete** ✅  
**Testing Scripts: 100% Complete** ✅  
**AWS Deployment: 0% Complete** ⏳ **READY TO EXECUTE**

This infrastructure will provide a robust, scalable foundation for asynchronous processing while integrating seamlessly with your existing S3 data pipeline.