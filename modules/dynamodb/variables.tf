variable "table_name" {
  description = "The name of the DynamoDB table"
  type        = string
}

variable "billing_mode" {
  description = "Billing mode for the DynamoDB table (e.g., PAY_PER_REQUEST)"
  type        = string
  default     = "PAY_PER_REQUEST"
}

variable "hash_key" {
  description = "The hash key for the DynamoDB table"
  type        = string
}

variable "hash_key_type" {
  description = "The type of the hash key (S, N, or B)"
  type        = string
  default     = "S"
}

variable "range_key" {
  description = "An optional range key for the DynamoDB table"
  type        = string
  default     = ""
}

variable "range_key_type" {
  description = "The type of the range key (S, N, or B)"
  type        = string
  default     = "S"
}

variable "tags" {
  description = "Tags for the DynamoDB table"
  type        = map(string)
  default     = {}
}
