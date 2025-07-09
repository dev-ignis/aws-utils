resource "aws_dynamodb_table" "this" {
  name           = var.table_name
  billing_mode   = var.billing_mode
  hash_key       = var.hash_key
  range_key      = var.range_key != "" ? var.range_key : null

  # Hash key attribute
  attribute {
    name = var.hash_key
    type = var.hash_key_type
  }

  # Range key attribute (if specified)
  dynamic "attribute" {
    for_each = var.range_key != "" ? [1] : []
    content {
      name = var.range_key
      type = var.range_key_type
    }
  }

  # Additional attributes for GSIs
  dynamic "attribute" {
    for_each = var.additional_attributes
    content {
      name = attribute.value.name
      type = attribute.value.type
    }
  }

  # Dynamic Global Secondary Indexes
  dynamic "global_secondary_index" {
    for_each = var.global_secondary_indexes
    content {
      name            = global_secondary_index.value.name
      hash_key        = global_secondary_index.value.hash_key
      range_key       = lookup(global_secondary_index.value, "range_key", null)
      projection_type = lookup(global_secondary_index.value, "projection_type", "ALL")
      
      # Only include non_key_attributes if projection_type is INCLUDE
      non_key_attributes = lookup(global_secondary_index.value, "projection_type", "ALL") == "INCLUDE" ? lookup(global_secondary_index.value, "non_key_attributes", []) : null
    }
  }

  tags = var.tags
}
