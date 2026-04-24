# EC2 snapshot cleaner (Lambda in VPC)

## What this does

On a **schedule** (for example once a day), AWS runs a small **Lambda** function. That function:

1. Lists **EBS snapshots** that belong to AWS account.
2. Finds snapshots older than a **cutoff** (default: **365 days**).
3. **Deletes** those old snapshots and writes lines to **CloudWatch Logs** to view what happened.

The function runs in a **private VPC** (no public subnet for the Lambda). It reaches EC2 and CloudWatch through **private network endpoints** inside the VPC, so this does not need a NAT gateway for this workload.

---

## How the flow works (big picture)

| Step | What happens |
|------|----------------|
| 1 | **EventBridge** triggers the Lambda on the schedule that is set in Terraform. |
| 2 | The Lambda uses an **IAM role** that allows logging, VPC networking, and EC2 snapshot list/delete. |
| 3 | Inside the VPC, traffic to **EC2** and **CloudWatch Logs** goes through **VPC interface endpoints** (private AWS APIs). |
| 4 | The Lambda calls EC2, deletes snapshots past retention, and emits logs/metrics like any other Lambda. |

Simple picture (read top to bottom):

```
                    ┌─────────────────┐
                    │  EventBridge    │
                    │  (daily timer)  │
                    └────────┬────────┘
                             │ invokes
                             ▼
┌──────────────────────────────────────────────────────────┐
│  VPC (private)                                           │
│  ┌────────────┐    ┌─────────────┐   ┌──────────────┐    │
│  │  Lambda    │───►│ EC2 endpoint│──► EC2 (snapshots)    │
│  │  (Python)  │    └─────────────┘   └──────────────┘    │
│  └─────┬──────┘    ┌─────────────┐   ┌──────────────┐    │
│        │           │Logs endpoint│──► CloudWatch    │    │
│        └──────────►└─────────────┘   └──────────────┘    │
└──────────────────────────────────────────────────────────┘
```

Terraform builds all of this. Code for the lambda function is in `src/lambda_function.py`. Infrastructure is split into **`terraform/`** (how to wire everything) and **`terraform-modules/`** (reusable **vpc** and **lambda_scheduler** pieces).

---

## What you need on your machine

- **Terraform** version 1.5 or newer  
- **AWS CLI** (optional, only if there is need to invoke the function by hand)  
- **AWS credentials** that are allowed to create VPCs, endpoints, IAM, Lambda, EventBridge, S3 (for state), and DynamoDB (for state lock)

---

## First-time setup (order matters)

### 1. State bucket and lock table (Terraform backend)

Open **`terraform/backend.tf`**. Replace the two **`DUMMY_*`** values with names that will actually use:

- **S3 bucket** — must be **globally unique**. This bucket only holds Terraform **state** (not  snapshots).
- **DynamoDB table** — any name related to task. It must have a **partition key** named **`LockID`**, type **String**. Terraform uses this row to avoid two people applying at once.

Create the bucket and table in AWS (console or CLI), turn on **versioning** on the bucket for extra safety, then continue.

### 2. Application settings (region, schedule, retention)

Open **`terraform/main.tf`**. In the **`locals { ... }`** block, set at least:

- **`aws_region`** — where everything is deployed (must match the **region** in `backend.tf` for the state bucket).  
- **`project_name`** — used in resource names and the log group path.  
- **`retention_days`** — snapshots newer than this are kept; older ones are deleted.  
- **`schedule_expression`** — when EventBridge runs the job (default is daily **03:00 UTC** in cron form).

### 3. Install providers and create infrastructure

```terminal
cd pennymac/terraform
terraform init
terraform plan -out=tfplan
terraform apply  tfplan
```

`terraform apply --auto-approve` automatically creates roughly: a small VPC with two private subnets, security groups, EC2 + Logs VPC endpoints, the Lambda and its IAM role, a log group, and the EventBridge schedule.


---

## After deploy

- See created values: **`terraform output`**
- Logs from the function: CloudWatch Logs group **`/aws/lambda/<project_name>`** (default project name is `snapshot-cleaner`).
- There is no need to attach the Lambda to the VPC in the console by hand; Terraform already sets subnets and security group.

---

## Change the Lambda code(Only if Lambda code needs change) [Optional]

Edit **`src/lambda_function.py`**, then from **`terraform/`** run **`terraform apply`** again. Terraform rebuilds the zip inside **`terraform-modules/lambda_scheduler/build/`** and updates the function.

---

## Run the function once (manual test)

Use the same **function name** and **region** as in  `locals`:

```terminal
aws lambda invoke \
  --function-name snapshot-cleaner \
  --payload '{"retention_days": 365}' \
  --cli-binary-format raw-in-base64-out \
  --region us-east-1 \
  out.json && cat out.json
```

---

## Project folders (short)

| Path | Role |
|------|------|
| `src/lambda_function.py` | Snapshot cleanup logic |
| `terraform/main.tf` |  `locals` + which modules to call |
| `terraform/backend.tf` | S3 state + DynamoDB lock |
| `terraform-modules/vpc/` | Network, endpoints, Lambda security group |
| `terraform-modules/lambda_scheduler/` | IAM, Lambda zip, logs, EventBridge |

---

## Safety

Deleting snapshots **cannot be undone**. Try in a **non-production** account first. If a snapshot is still needed by an AMI or another dependency, EC2 will refuse deletion; those errors appear in the logs and the run continues with the rest.
