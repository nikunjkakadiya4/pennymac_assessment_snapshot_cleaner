# Exposes the deployed Lambda function name for CLI invocations and operations runbooks.
output "lambda_function_name" {
  value = module.lambda_scheduler.lambda_function_name
}

# Full ARN of the Lambda function (e.g. for IAM conditions or cross-stack references).
output "lambda_arn" {
  value = module.lambda_scheduler.lambda_arn
}

# VPC containing private subnets and VPC endpoints used by the cleaner.
output "vpc_id" {
  value = module.vpc.vpc_id
}

# Private subnet IDs passed to Lambda; useful when re-attaching or debugging VPC config.
output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}

# Security group attached to Lambda ENIs (egress toward VPC endpoints inside the VPC CIDR).
output "lambda_security_group_id" {
  value = module.vpc.lambda_security_group_id
}

# EventBridge rule name that fires the scheduled cleanup.
output "eventbridge_rule_name" {
  value = module.lambda_scheduler.eventbridge_rule_name
}

# CloudWatch Logs group where Lambda stdout/stderr is written.
output "cloudwatch_log_group" {
  value = module.lambda_scheduler.cloudwatch_log_group
}
