resource "aws_lambda_function" "this" {
  function_name = "meaning-mesh-main-service-${var.environment}"
  role          = var.role_arn
  runtime       = "python3.11"
  handler       = "app.handler.lambda_handler"
  filename      = var.package_file
  timeout       = 3
  source_code_hash = filebase64sha256(var.package_file)

  environment {
    variables = var.environment_variables
  }

  tags = {
    Project     = "meaning-mesh"
    Environment = var.environment
    Service     = "main-service"
  }
}
