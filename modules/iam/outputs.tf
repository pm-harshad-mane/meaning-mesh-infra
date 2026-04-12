output "main_lambda_role_arn" {
  value = aws_iam_role.main_lambda_role.arn
}

output "fetcher_lambda_role_arn" {
  value = aws_iam_role.fetcher_lambda_role.arn
}

output "categorizer_task_role_arn" {
  value = aws_iam_role.categorizer_task_role.arn
}

output "categorizer_execution_role_arn" {
  value = aws_iam_role.categorizer_execution_role.arn
}
