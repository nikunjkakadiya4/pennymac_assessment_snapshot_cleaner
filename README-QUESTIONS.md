# Answers (requirements checklist)

1. The chosen IaC tool and why?

The chosen IaC tool is Terraform. It is used because it:
Describes AWS resources declaratively.
Supports reusable modules (terraform-modules/vpc, terraform-modules/lambda_scheduler).
Packages the Lambda artifact using the archive provider.
Enables plan / apply workflows with a remote S3 backend and DynamoDB for state locking (configured in this repository).

-----------------------------------------------------------------------------------------------------------------------------------------

2. How to execute the IaC to create the infrastructure (VPC, subnet, IAM role, CloudWatch Event Rule if included)?

Infrastructure Creation Steps

To execute the IaC and create the infrastructure (VPC, subnets, IAM role, EventBridge rule, etc.):
Configure Backend: In terraform/backend.tf, replace the placeholder DUMMY_* S3 bucket and DynamoDB table names with actual values. Create the specified S3 bucket and a DynamoDB table with the partition key LockID (String).
Set Locals: In terraform/main.tf, configure the necessary locals (e.g., region, project name, retention period, schedule, Lambda settings).
Execute Terraform: From the terraform/ directory, run the following commands:

   terraform init
   terraform plan -out=tfplan
   terraform apply tfplan


This process creates: a VPC, two private subnets, a private route table, subnet associations, security groups for the Lambda and VPC endpoints, interface VPC endpoints for EC2 and CloudWatch Logs, an IAM role and policies for the Lambda, the Lambda function and its CloudWatch log group, and the EventBridge schedule and target with necessary permissions.

-----------------------------------------------------------------------------------------------------------------------------------------

3. How to deploy the Lambda function code? 


The initial terraform apply deploys the Lambda function code.
To update the Lambda function code (src/lambda_function.py) via Terraform: Edit the file, then run terraform apply again from terraform/. This triggers the lambda_scheduler module to rebuild the zip, update the Lambda's source_code_hash, and deploy the change.
Via AWS CLI (Alternative): Build a zip containing lambda_function.py and run aws lambda update-function-code using the appropriate --function-name and --region.

-----------------------------------------------------------------------------------------------------------------------------------------

4. How to configure the Lambda function to run within the VPC (subnet IDs, security group IDs).

VPC Configuration for Lambda

The Lambda function is configured to run within the VPC directly in Terraform. The module "lambda_scheduler" passes the necessary configuration:
Subnet IDs: private_subnet_ids from module.vpc.
Security Group ID: lambda_security_group_id from module.vpc.
These are set on the aws_lambda_function resource's vpc_config.
The subnet and security group IDs can be retrieved post-apply using terraform output for private_subnet_ids and lambda_security_group_id.5. Implementation 

-----------------------------------------------------------------------------------------------------------------------------------------
5. Any assumptions made during the implementation (e.g., AWS region)?

Assumptions

The following assumptions were made during implementation:
AWS Region: The default us-east-1 is used for the provider and sample backend (locals.aws_region in terraform/main.tf). The backend.tf region must match the state bucket region.
Networking: The infrastructure uses two private subnets across two Availability Zones. Default CIDRs are 10.42.0.0/16 (VPC) and 10.42.1.0/24, 10.42.2.0/24 (subnets).
Snapshots: The Lambda processes account-owned snapshots (OwnerIds=["self"] in the Lambda code).
Retention/Schedule: Default retention is 365 days, and the schedule is daily at 03:00 UTC (cron(0 3 * * ? *)).
Service Access: The Lambda accesses EC2 and CloudWatch Logs via interface VPC endpoints, not a NAT gateway.
Terraform State: S3 is used for remote state and DynamoDB is used for state locking (placeholder names must be replaced).

-----------------------------------------------------------------------------------------------------------------------------------------

6. How you would monitor the Lambda function's execution (e.g., CloudWatch Logs, CloudWatch Metrics)?

Monitoring the Lambda Function

Monitoring is achieved using standard AWS services:
CloudWatch Logs: Handler logs are written to the log group /aws/lambda/<project_name> (default <project_name> is snapshot-cleaner).
CloudWatch Metrics: Utilizes the built-in Lambda metrics in the AWS/Lambda namespace (e.g., Invocations, Errors, Duration, Throttles).
Alarms (Optional): CloudWatch alarms can be created based on Errors or Duration thresholds, or via metric filters on log patterns.

-----------------------------------------------------------------------------------------------------------------------------------------

7. Design Diagram

The Design Diagram is in diagrams folder