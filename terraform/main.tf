# Root stack: central place for environment values (no .tfvars). Change locals to tune region, names, retention, and Lambda sizing.
locals {
  aws_region             = "us-east-1"
  project_name           = "snapshot-cleaner"
  retention_days         = 365 # default retention window
  schedule_expression    = "cron(0 3 * * ? *)" # daily at 03:00 UTC
  lambda_runtime         = "python3.12" 
  lambda_timeout_seconds = 300 # default timeout
  lambda_memory_mb       = 256 # default memory
}

# Configures the default AWS provider used by all resources and child modules in this root.
provider "aws" {
  region = local.aws_region
}

# Provisions the isolated network: private subnets, route table, interface VPC endpoints (EC2 + Logs), and security groups for Lambda and endpoints.
module "vpc" {
  source = "../terraform-modules/vpc"

  project_name = local.project_name
  aws_region   = local.aws_region
}

# Provisions IAM for Lambda, zips and deploys the Python handler, CloudWatch log group, VPC-attached Lambda, and EventBridge schedule + invoke permission.
module "lambda_scheduler" {
  source = "../terraform-modules/lambda_scheduler"

  project_name             = local.project_name
  retention_days           = local.retention_days
  schedule_expression      = local.schedule_expression
  lambda_runtime           = local.lambda_runtime
  lambda_timeout_seconds   = local.lambda_timeout_seconds
  lambda_memory_mb         = local.lambda_memory_mb
  private_subnet_ids       = module.vpc.private_subnet_ids
  lambda_security_group_id = module.vpc.lambda_security_group_id
  lambda_source_file       = "${abspath(path.module)}/../src/lambda_function.py"
}
