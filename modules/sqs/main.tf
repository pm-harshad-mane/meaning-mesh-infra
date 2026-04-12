resource "aws_sqs_queue" "url_fetcher_service_dlq" {
  name = "url_fetcher_service_dlq"

  tags = {
    Project     = "meaning-mesh"
    Environment = var.environment
    Service     = "fetcher"
  }
}

resource "aws_sqs_queue" "url_fetcher_service_queue" {
  name                       = "url_fetcher_service_queue"
  visibility_timeout_seconds = 30
  message_retention_seconds  = 345600
  receive_wait_time_seconds  = 10

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.url_fetcher_service_dlq.arn
    maxReceiveCount     = 5
  })

  tags = {
    Project     = "meaning-mesh"
    Environment = var.environment
    Service     = "fetcher"
  }
}

resource "aws_sqs_queue" "url_categorizer_service_dlq" {
  name = "url_categorizer_service_dlq"

  tags = {
    Project     = "meaning-mesh"
    Environment = var.environment
    Service     = "categorizer"
  }
}

resource "aws_sqs_queue" "url_categorizer_service_queue" {
  name                       = "url_categorizer_service_queue"
  visibility_timeout_seconds = 300
  message_retention_seconds  = 345600
  receive_wait_time_seconds  = 10

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.url_categorizer_service_dlq.arn
    maxReceiveCount     = 5
  })

  tags = {
    Project     = "meaning-mesh"
    Environment = var.environment
    Service     = "categorizer"
  }
}
