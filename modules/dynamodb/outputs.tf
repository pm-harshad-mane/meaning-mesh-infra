output "url_categorization_table_name" {
  value = aws_dynamodb_table.url_categorization.name
}

output "url_categorization_table_arn" {
  value = aws_dynamodb_table.url_categorization.arn
}

output "url_wip_table_name" {
  value = aws_dynamodb_table.url_wip.name
}

output "url_wip_table_arn" {
  value = aws_dynamodb_table.url_wip.arn
}
