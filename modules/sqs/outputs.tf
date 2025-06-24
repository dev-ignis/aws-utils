# White Label SQS Module Outputs

# Queue Information
output "queue_urls" {
  description = "URLs of all created SQS queues"
  value = {
    for k, v in aws_sqs_queue.main_queues : k => v.url
  }
}

output "queue_arns" {
  description = "ARNs of all created SQS queues"
  value = {
    for k, v in aws_sqs_queue.main_queues : k => v.arn
  }
}

output "queue_names" {
  description = "Names of all created SQS queues"
  value = {
    for k, v in aws_sqs_queue.main_queues : k => v.name
  }
}

# Dead Letter Queue Information
output "dlq_urls" {
  description = "URLs of all dead letter queues"
  value = {
    for k, v in aws_sqs_queue.dead_letter_queues : k => v.url
  }
}

output "dlq_arns" {
  description = "ARNs of all dead letter queues"
  value = {
    for k, v in aws_sqs_queue.dead_letter_queues : k => v.arn
  }
}

output "dlq_names" {
  description = "Names of all dead letter queues"
  value = {
    for k, v in aws_sqs_queue.dead_letter_queues : k => v.name
  }
}

# IAM Role Information
output "api_service_role_arn" {
  description = "ARN of the API service IAM role"
  value       = var.create_api_service_role ? aws_iam_role.api_service_role[0].arn : ""
}

output "api_service_role_name" {
  description = "Name of the API service IAM role"
  value       = var.create_api_service_role ? aws_iam_role.api_service_role[0].name : ""
}

output "worker_service_role_arn" {
  description = "ARN of the worker service IAM role"
  value       = var.create_worker_service_role ? aws_iam_role.worker_service_role[0].arn : ""
}

output "worker_service_role_name" {
  description = "Name of the worker service IAM role"
  value       = var.create_worker_service_role ? aws_iam_role.worker_service_role[0].name : ""
}

# Instance Profile Information
output "api_service_instance_profile_name" {
  description = "Name of the API service instance profile"
  value       = var.create_api_service_role && var.create_instance_profiles ? aws_iam_instance_profile.api_service_profile[0].name : ""
}

output "worker_service_instance_profile_name" {
  description = "Name of the worker service instance profile"
  value       = var.create_worker_service_role && var.create_instance_profiles ? aws_iam_instance_profile.worker_service_profile[0].name : ""
}

# CloudWatch Information
output "cloudwatch_alarm_names" {
  description = "Names of CloudWatch alarms created for queue monitoring"
  value = var.enable_cloudwatch_alarms ? {
    queue_depth = {
      for k, v in aws_cloudwatch_metric_alarm.queue_depth_alarm : k => v.alarm_name
    }
    dlq_depth = {
      for k, v in aws_cloudwatch_metric_alarm.dlq_alarm : k => v.alarm_name
    }
  } : {}
}

output "operations_log_group_name" {
  description = "Name of the CloudWatch log group for SQS operations"
  value       = var.enable_operations_logging ? aws_cloudwatch_log_group.sqs_operations[0].name : ""
}

# Integration Information
output "integration_guide" {
  description = "Integration patterns and usage examples for the SQS queues"
  value = {
    send_message_examples = {
      nodejs = "const AWS = require('aws-sdk'); const sqs = new AWS.SQS(); await sqs.sendMessage({QueueUrl: '${values(aws_sqs_queue.main_queues)[0].url}', MessageBody: JSON.stringify(payload)}).promise();"
      python = "import boto3; sqs = boto3.client('sqs'); sqs.send_message(QueueUrl='${values(aws_sqs_queue.main_queues)[0].url}', MessageBody=json.dumps(payload))"
      go     = "sess := session.Must(session.NewSession()); svc := sqs.New(sess); svc.SendMessage(&sqs.SendMessageInput{QueueUrl: aws.String(\"${values(aws_sqs_queue.main_queues)[0].url}\"), MessageBody: aws.String(messageBody)})"
    }
    receive_message_examples = {
      nodejs = "const messages = await sqs.receiveMessage({QueueUrl: '${values(aws_sqs_queue.main_queues)[0].url}', WaitTimeSeconds: 20}).promise();"
      python = "messages = sqs.receive_message(QueueUrl='${values(aws_sqs_queue.main_queues)[0].url}', WaitTimeSeconds=20)"
      go     = "result, err := svc.ReceiveMessage(&sqs.ReceiveMessageInput{QueueUrl: aws.String(\"${values(aws_sqs_queue.main_queues)[0].url}\"), WaitTimeSeconds: aws.Int64(20)})"
    }
    environment_variables = {
      for k, v in aws_sqs_queue.main_queues : "${upper(k)}_QUEUE_URL" => v.url
    }
  }
}

# Queue Configuration Summary
output "queue_configuration_summary" {
  description = "Summary of queue configurations and settings"
  value = {
    total_queues     = length(aws_sqs_queue.main_queues)
    total_dlqs      = length(aws_sqs_queue.dead_letter_queues)
    encryption      = var.enable_encryption ? "Enabled" : "Disabled"
    environment     = var.environment
    use_case        = var.use_case
    queue_types = {
      for k, v in var.queue_configurations : k => {
        type                    = v.fifo_queue ? "FIFO" : "Standard"
        retention_days         = v.message_retention_seconds / 86400
        visibility_timeout_min = v.visibility_timeout_seconds / 60
        dlq_enabled           = v.enable_dlq
      }
    }
  }
}

# White Label Configuration
output "white_label_configuration" {
  description = "White label configuration summary for replication"
  value = {
    instance_name    = var.instance_name
    use_case        = var.use_case
    naming_pattern  = "${var.instance_name}-${var.use_case}-{queue_name}"
    fifo_suffix     = ".fifo"
    dlq_suffix      = "-dlq"
    encryption      = var.enable_encryption
    multi_tenant    = var.enable_multi_tenant_queues
    environment     = var.environment
  }
}

# Cost Optimization Features
output "cost_optimization_features" {
  description = "Summary of cost optimization features enabled"
  value = {
    long_polling_enabled     = "All queues configured with 20s wait time"
    fifo_queues_optimized   = "Content-based deduplication where appropriate"
    dlq_retention_optimized = "DLQs configured with ${var.dlq_message_retention_seconds / 86400} day retention"
    encryption_managed      = var.kms_key_id == null ? "AWS managed keys (no additional cost)" : "Customer managed keys"
    monitoring_enabled      = var.enable_cloudwatch_alarms ? "CloudWatch alarms configured" : "Basic monitoring only"
  }
}

# Monitoring Dashboard Configuration
output "cloudwatch_dashboard_config" {
  description = "CloudWatch dashboard configuration for SQS monitoring"
  value = var.enable_cloudwatch_alarms ? {
    dashboard_name = "${var.instance_name}-${var.use_case}-sqs-monitoring"
    metrics = {
      for k, v in aws_sqs_queue.main_queues : k => {
        queue_name = v.name
        metrics = [
          "ApproximateNumberOfVisibleMessages",
          "ApproximateNumberOfMessagesDelayed",
          "ApproximateAgeOfOldestMessage",
          "NumberOfMessagesSent",
          "NumberOfMessagesReceived",
          "NumberOfMessagesDeleted"
        ]
      }
    }
    alarms = {
      for k, v in aws_cloudwatch_metric_alarm.queue_depth_alarm : k => v.alarm_name
    }
  } : {
    dashboard_name = ""
    metrics = {}
    alarms = {}
  }
}

# API Integration Templates
output "api_integration_templates" {
  description = "Ready-to-use API integration templates"
  value = {
    express_middleware = "// Express.js middleware\nconst { sendToQueue } = require('./sqs-helper');\napp.post('/api/feedback', async (req, res) => {\n  await sendToQueue('${aws_sqs_queue.main_queues["feedback"].url}', req.body);\n  res.json({ status: 'queued', requestId: req.id });\n});"
    
    worker_processor = "// Background worker\nconst { receiveFromQueue, deleteMessage } = require('./sqs-helper');\nwhile (true) {\n  const messages = await receiveFromQueue('${aws_sqs_queue.main_queues["feedback"].url}');\n  for (const message of messages) {\n    await processMessage(message);\n    await deleteMessage(message.ReceiptHandle);\n  }\n}"
    
    s3_integration = var.enable_s3_integration ? "// Store results in S3\nconst s3Key = `processed/$${new Date().getFullYear()}/$${new Date().getMonth() + 1}/$${new Date().getDate()}/$${Date.now()}.json`;\nawait s3.putObject({ Bucket: '${replace(var.s3_bucket_arn, "arn:aws:s3:::", "")}', Key: s3Key, Body: JSON.stringify(result) }).promise();" : ""
  }
}