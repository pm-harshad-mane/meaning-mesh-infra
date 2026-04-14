resource "aws_lambda_function" "this" {
  function_name    = "meaning-mesh-url-fetcher-${var.environment}"
  role             = var.role_arn
  runtime          = "python3.11"
  handler          = "app.handler.lambda_handler"
  filename         = var.package_file
  timeout          = 15
  memory_size      = 512
  source_code_hash = filebase64sha256(var.package_file)
  architectures    = ["arm64"]

  environment {
    variables = var.environment_variables
  }

  tags = {
    Project     = "meaning-mesh"
    Environment = var.environment
    Service     = "fetcher"
  }
}

resource "aws_lambda_event_source_mapping" "fetch_queue" {
  event_source_arn = var.fetch_queue_arn
  function_name    = aws_lambda_function.this.arn
  batch_size       = 10
  enabled          = true
}
