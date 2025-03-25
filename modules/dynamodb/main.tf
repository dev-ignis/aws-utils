resource "aws_dynamodb_table" "this" {
  name           = var.table_name
  billing_mode   = var.billing_mode
  hash_key       = var.hash_key

  attribute {
    name = var.hash_key
    type = var.hash_key_type
  }

  # Add an attribute for email
  attribute {
    name = "Email"
    type = "S"
  }

  # Create a Global Secondary Index on the email attribute
  global_secondary_index {
    name            = "email-index"
    hash_key        = "Email"
    projection_type = "ALL"
  }

  tags = var.tags
}
