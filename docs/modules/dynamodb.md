# DynamoDB Module

## Overview

The DynamoDB module creates a managed NoSQL database table with predefined global secondary indexes (GSIs) for email and Apple ID lookups. This module is designed for applications requiring fast, flexible data storage with support for user authentication and profile management.

## Architecture

### Table Configuration

1. **Primary Key**
   - Configurable hash key (partition key)
   - Optional range key support (sort key)
   - Default type: String (S)

2. **Billing Mode**
   - Default: PAY_PER_REQUEST (on-demand)
   - No capacity planning required
   - Automatic scaling

3. **Global Secondary Indexes**
   - **email-index**: Query by Email attribute
   - **apple_id-index**: Query by AppleId attribute
   - Both indexes project all attributes

### Predefined Attributes

The module creates three required attributes:
- Primary hash key (configurable name)
- `Email` (String) - For email-based queries
- `AppleId` (String) - For Apple ID authentication

## Module Interface

### Input Variables

| Variable | Description | Type | Required | Default |
|----------|-------------|------|----------|---------|
| `table_name` | Name of the DynamoDB table | `string` | Yes | - |
| `billing_mode` | Billing mode (PAY_PER_REQUEST or PROVISIONED) | `string` | No | `PAY_PER_REQUEST` |
| `hash_key` | Name of the hash key attribute | `string` | Yes | - |
| `hash_key_type` | Type of hash key (S, N, or B) | `string` | No | `S` |
| `range_key` | Name of the range key attribute | `string` | No | `""` |
| `range_key_type` | Type of range key (S, N, or B) | `string` | No | `S` |
| `tags` | Resource tags | `map(string)` | No | `{}` |

### Output Values

| Output | Description | Type |
|--------|-------------|------|
| `table_name` | Name of the created table | `string` |
| `table_arn` | ARN of the created table | `string` |

## Global Secondary Indexes

### email-index
- **Partition Key**: Email (String)
- **Projection Type**: ALL
- **Use Case**: Find users by email address
- **Query Pattern**: `Email = :email`

### apple_id-index
- **Partition Key**: AppleId (String)
- **Projection Type**: ALL
- **Use Case**: Find users by Apple ID
- **Query Pattern**: `AppleId = :appleId`

## Usage Example

```hcl
module "dynamodb" {
  source        = "./modules/dynamodb"
  table_name    = "my-app-users"
  billing_mode  = "PAY_PER_REQUEST"
  hash_key      = "UserId"
  hash_key_type = "S"
  tags = {
    Environment = "production"
    Application = "my-app"
  }
}
```

## Data Model Considerations

### Primary Key Design
- Choose a hash key with high cardinality
- Consider using UUIDs for even distribution
- Add range key for one-to-many relationships

### Attribute Requirements
Every item must include:
- The hash key attribute
- Email attribute (if using email-index)
- AppleId attribute (if using apple_id-index)

### Example Item Structure
```json
{
  "UserId": "123e4567-e89b-12d3-a456-426614174000",
  "Email": "user@example.com",
  "AppleId": "001234.56789abcdef.1234",
  "Name": "John Doe",
  "CreatedAt": "2024-01-01T00:00:00Z",
  "ProfileData": {
    "Avatar": "https://...",
    "Preferences": {}
  }
}
```

## Performance Characteristics

### On-Demand Billing (Default)
- **Pros**:
  - No capacity planning
  - Handles traffic spikes automatically
  - Pay only for actual usage
- **Cons**:
  - Higher per-request cost
  - Cold start latency possible

### Global Secondary Indexes
- Eventually consistent reads
- Separate throughput from base table
- Query performance same as base table

## Security Considerations

1. **Encryption**
   - Encryption at rest enabled by default
   - Uses AWS managed keys
   - Consider customer managed keys for compliance

2. **Access Control**
   - Use IAM policies for fine-grained access
   - Consider VPC endpoints for private access
   - Implement least privilege principle

3. **Data Protection**
   - Enable point-in-time recovery
   - Set up automated backups
   - Consider cross-region replication

## Cost Optimization

### On-Demand Pricing Factors
- Read request units (RRU)
- Write request units (WRU)
- Storage (per GB-month)
- Global secondary index usage

### Cost Reduction Strategies
1. Use projection expressions to limit data transfer
2. Batch operations when possible
3. Consider provisioned capacity for predictable workloads
4. Monitor and optimize GSI usage

## Limitations

### Module Constraints
- Fixed GSI structure (Email and AppleId)
- No support for local secondary indexes
- Range key configuration not fully implemented
- Limited to three predefined attributes

### DynamoDB Limits
- Item size: 400 KB maximum
- Partition key value: 2048 bytes maximum
- Sort key value: 1024 bytes maximum

## Monitoring and Troubleshooting

### Key Metrics to Monitor
- ConsumedReadCapacityUnits
- ConsumedWriteCapacityUnits
- UserErrors and SystemErrors
- ThrottledRequests

### Common Issues

1. **Throttling**
   - Switch to on-demand if using provisioned
   - Implement exponential backoff
   - Review access patterns

2. **Hot Partitions**
   - Ensure even key distribution
   - Avoid sequential keys
   - Consider key sharding

3. **GSI Throttling**
   - Monitor GSI metrics separately
   - Consider GSI projection optimization

### Debug Commands

```bash
# Describe table
aws dynamodb describe-table --table-name my-app-users

# Query by email
aws dynamodb query \
  --table-name my-app-users \
  --index-name email-index \
  --key-condition-expression "Email = :email" \
  --expression-attribute-values '{":email":{"S":"user@example.com"}}'

# Check table metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/DynamoDB \
  --metric-name ConsumedReadCapacityUnits \
  --dimensions Name=TableName,Value=my-app-users \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-01T01:00:00Z \
  --period 300 \
  --statistics Sum
```

## Best Practices

1. **Key Design**
   - Use UUIDs for even distribution
   - Avoid hot keys (timestamps, sequential IDs)
   - Consider composite keys for complex queries

2. **Index Usage**
   - Only project needed attributes
   - Monitor index utilization
   - Consider sparse indexes

3. **Application Design**
   - Implement retry logic with backoff
   - Use batch operations
   - Cache frequently accessed data

4. **Backup Strategy**
   - Enable point-in-time recovery
   - Schedule regular backups
   - Test restore procedures

## Future Enhancements

Consider these improvements:
- Configurable GSI structure
- Support for local secondary indexes
- Automated backup configuration
- Stream enablement for change capture
- Custom KMS key support

## Related Documentation

- [DynamoDB Best Practices](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/best-practices.html)
- [Global Secondary Indexes](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/GSI.html)
- [DynamoDB Pricing](https://aws.amazon.com/dynamodb/pricing/)