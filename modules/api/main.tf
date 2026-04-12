resource "aws_apigatewayv2_api" "this" {
  name          = "meaning-mesh-api-${var.environment}"
  protocol_type = "HTTP"

  tags = {
    Project     = "meaning-mesh"
    Environment = var.environment
    Service     = "api"
  }
}

resource "aws_apigatewayv2_integration" "main_lambda" {
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_uri        = var.lambda_invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "categorize" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "POST /categorize"
  target    = "integrations/${aws_apigatewayv2_integration.main_lambda.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "api_invoke" {
  statement_id  = "AllowExecutionFromApiGateway"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}
