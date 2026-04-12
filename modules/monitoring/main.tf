resource "aws_cloudwatch_dashboard" "meaning_mesh" {
  dashboard_name = "meaning-mesh-${var.environment}"
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 4
        properties = {
          markdown = "Meaning-Mesh operational dashboard skeleton. Add queue depth, Lambda error rate, DynamoDB throttles, and ECS CPU metrics here."
        }
      }
    ]
  })
}

resource "aws_cloudwatch_metric_alarm" "fetch_dlq_visible" {
  alarm_name          = "meaning-mesh-fetch-dlq-visible-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0

  dimensions = {
    QueueName = var.fetch_dlq_name
  }
}

resource "aws_cloudwatch_metric_alarm" "categorizer_dlq_visible" {
  alarm_name          = "meaning-mesh-categorizer-dlq-visible-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0

  dimensions = {
    QueueName = var.categorizer_dlq_name
  }
}
