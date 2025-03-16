resource "aws_dynamodb_table" "this" {
  name         = var.table_name
  billing_mode = var.billing_mode

  hash_key     = var.hash_key

  attribute {
    name = var.hash_key
    type = var.hash_key_type
  }

  # Optionally add a range key if provided
  dynamic "attribute" {
    for_each = var.range_key != "" ? [var.range_key] : []
    content {
      name = var.range_key
      type = var.range_key_type
    }
  }

  tags = var.tags
}
