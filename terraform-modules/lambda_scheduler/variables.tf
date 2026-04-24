# Function name and default log group path segment /aws/lambda/<project_name>.
variable "project_name" {
  type = string
}

# Snapshots newer than this many days are kept; older are candidates for deletion in the handler.
variable "retention_days" {
  type    = number
  default = 365
}

# EventBridge schedule for periodic runs (cron or rate expression).
variable "schedule_expression" {
  type    = string
  default = "cron(0 3 * * ? *)"
}

# Managed language runtime for the Lambda (must match handler code compatibility).
variable "lambda_runtime" {
  type    = string
  default = "python3.12"
}

# Maximum seconds a single invocation may run (large snapshot counts may need more).
variable "lambda_timeout_seconds" {
  type    = number
  default = 300
}

# Memory size for the Lambda execution environment (affects CPU proportionally).
variable "lambda_memory_mb" {
  type    = number
  default = 256
}

# From vpc module: subnets where Lambda ENIs are placed.
variable "private_subnet_ids" {
  description = "Private subnet IDs for Lambda VPC config."
  type        = list(string)
}

# From vpc module: SG controlling Lambda egress (HTTPS toward VPC endpoints).
variable "lambda_security_group_id" {
  description = "Security group ID attached to the Lambda ENIs."
  type        = string
}

# Absolute path to lambda_function.py on the machine running terraform (archive_file reads this path).
variable "lambda_source_file" {
  description = "Absolute or module-relative path to lambda_function.py (usually passed from root path.module)."
  type        = string
}

# Days to retain CloudWatch log events for this function’s log group.
variable "log_retention_in_days" {
  type    = number
  default = 14
}
