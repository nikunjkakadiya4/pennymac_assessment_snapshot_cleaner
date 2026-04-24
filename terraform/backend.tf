# Replace DUMMY_* values with your real S3 bucket (globally unique), region, and DynamoDB lock table.
# Lock table needs partition key LockID (String). Enable S3 versioning on the state bucket in production.
terraform {
  backend "s3" {
    bucket         = "DUMMY_tfstate_bucket_name_change_me"
    key            = "snapshot-cleaner/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "DUMMY_terraform_state_lock_change_me"
    encrypt        = true
  }
}
