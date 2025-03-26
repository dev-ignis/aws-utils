resource "aws_dynamodb_table" "this" {
  name           = var.table_name
  billing_mode   = var.billing_mode
  hash_key       = var.hash_key

  attribute {
    name = var.hash_key
    type = var.hash_key_type
  }

  # Attribute for Email
  attribute {
    name = "Email"
    type = "S"
  }

  # Attribute for AppleId
  attribute {
    name = "AppleId"
    type = "S"
  }

  # Global Secondary Index on Email
  global_secondary_index {
    name            = "email-index"
    hash_key        = "Email"
    projection_type = "ALL"
  }

  # Global Secondary Index on AppleId
  global_secondary_index {
    name            = "apple_id-index"
    hash_key        = "AppleId"
    projection_type = "ALL"
  }

  tags = var.tags
}
