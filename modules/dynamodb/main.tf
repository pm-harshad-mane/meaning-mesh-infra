resource "aws_dynamodb_table" "url_categorization" {
  name         = "url_categorization"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "url_hash"

  attribute {
    name = "url_hash"
    type = "S"
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  tags = {
    Project     = "meaning-mesh"
    Environment = var.environment
    Service     = "storage"
    Table       = "url_categorization"
  }
}

resource "aws_dynamodb_table" "url_wip" {
  name         = "url_wip"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "url_hash"

  attribute {
    name = "url_hash"
    type = "S"
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  tags = {
    Project     = "meaning-mesh"
    Environment = var.environment
    Service     = "storage"
    Table       = "url_wip"
  }
}
