output "api_endpoint" {
  value = module.api.api_endpoint
}

output "fetch_queue_url" {
  value = module.sqs.fetch_queue_url
}

output "categorizer_queue_url" {
  value = module.sqs.categorizer_queue_url
}
