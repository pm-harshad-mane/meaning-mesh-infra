output "fetch_queue_url" {
  value = aws_sqs_queue.url_fetcher_service_queue.id
}

output "fetch_queue_arn" {
  value = aws_sqs_queue.url_fetcher_service_queue.arn
}

output "fetch_dlq_arn" {
  value = aws_sqs_queue.url_fetcher_service_dlq.arn
}

output "categorizer_queue_url" {
  value = aws_sqs_queue.url_categorizer_service_queue.id
}

output "categorizer_queue_arn" {
  value = aws_sqs_queue.url_categorizer_service_queue.arn
}

output "categorizer_dlq_arn" {
  value = aws_sqs_queue.url_categorizer_service_dlq.arn
}
