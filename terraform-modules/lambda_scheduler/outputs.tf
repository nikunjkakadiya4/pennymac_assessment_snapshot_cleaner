# Same as aws_lambda_function.snapshot_cleaner.function_name (handy for aws lambda invoke).
output "lambda_function_name" {
  value = aws_lambda_function.snapshot_cleaner.function_name
}

# ARN of the deployed function (for alarms, permissions, or cross-stack references).
output "lambda_arn" {
  value = aws_lambda_function.snapshot_cleaner.arn
}

# Name of the EventBridge rule that triggers scheduled cleanups.
output "eventbridge_rule_name" {
  value = aws_cloudwatch_event_rule.daily.name
}

# Full name of the log group receiving Lambda platform and application logs.
output "cloudwatch_log_group" {
  value = aws_cloudwatch_log_group.lambda.name
}
