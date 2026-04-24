# Trust policy: allows the Lambda service to assume the execution role at invoke time.
# JSON trust policy consumed by aws_iam_role.lambda (who may assume this role).
data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# IAM role attached to the snapshot-cleaner function (identity Lambda runs as).
resource "aws_iam_role" "lambda" {
  name               = "${var.project_name}-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json

  tags = {
    Name = "${var.project_name}-lambda-role"
  }
}

# Grants CloudWatch Logs write access for function logs (standard Lambda logging).
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Allows Lambda to create/manage ENIs when attached to a VPC (required for vpc_config).
resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Inline policy document listing EC2 snapshot APIs the cleaner is allowed to call.
# JSON permissions policy for EC2 snapshot list/delete used by aws_iam_role_policy.lambda_ec2.
data "aws_iam_policy_document" "lambda_ec2" {
  statement {
    sid = "Ec2SnapshotMaintenance"
    actions = [
      "ec2:DescribeSnapshots",
      "ec2:DeleteSnapshot",
    ]
    resources = ["*"]
  }
}

# Attaches the EC2 snapshot maintenance policy to the Lambda role.
resource "aws_iam_role_policy" "lambda_ec2" {
  name   = "${var.project_name}-ec2-snapshots"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda_ec2.json
}

# Produces a zip artifact on disk and a hash Terraform uses to detect code changes on apply.
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = var.lambda_source_file
  output_path = "${path.module}/build/lambda_function.zip"
}

# Log group created up front so logging works on first invocation and retention can be enforced.
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.project_name}"
  retention_in_days = var.log_retention_in_days
}

# The snapshot cleanup function: runs in private subnets, uses RETENTION_DAYS from environment.
resource "aws_lambda_function" "snapshot_cleaner" {
  function_name    = var.project_name
  role             = aws_iam_role.lambda.arn
  handler          = "lambda_function.handler"
  runtime          = var.lambda_runtime
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = var.lambda_timeout_seconds
  memory_size      = var.lambda_memory_mb

  depends_on = [aws_cloudwatch_log_group.lambda]

  # Places Lambda ENIs in the VPC module’s private subnets with the Lambda security group.
  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }

  # Passed into Python as os.environ for snapshot age threshold (days).
  environment {
    variables = {
      RETENTION_DAYS = tostring(var.retention_days)
    }
  }

  tags = {
    Name = var.project_name
  }
}

# EventBridge rule defining when the cleaner runs (cron or rate expression from variable).
resource "aws_cloudwatch_event_rule" "daily" {
  name                = "${var.project_name}-daily"
  description         = "Trigger snapshot cleanup Lambda on a schedule"
  schedule_expression = var.schedule_expression

  tags = {
    Name = "${var.project_name}-daily"
  }
}

# Wires the schedule rule to invoke this Lambda’s ARN on each firing.
resource "aws_cloudwatch_event_target" "lambda" {
  rule      = aws_cloudwatch_event_rule.daily.name
  target_id = "SnapshotCleanerLambda"
  arn       = aws_lambda_function.snapshot_cleaner.arn
}

# Resource-based policy: permits EventBridge service to invoke this specific function for this rule only.
resource "aws_lambda_permission" "eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.snapshot_cleaner.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily.arn
}
