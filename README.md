# meaning-mesh-infra

Terraform infrastructure for Meaning-Mesh on AWS `us-east-1`.

Included modules:

- API Gateway HTTP API
- DynamoDB tables for `url_categorization` and `url_wip`
- SQS queues and DLQs
- Main Lambda
- Fetcher Lambda
- ECS categorizer service skeleton
- IAM roles and least-privilege policies
- CloudWatch monitoring skeleton

## Layout

```text
environments/
  dev/
  stage/
  prod/
modules/
  api/
  dynamodb/
  lambda_main/
  lambda_fetcher/
  sqs/
  ecs_categorizer/
  monitoring/
  iam/
```

## Usage

Each environment expects deployment artifacts to be provided explicitly:

- `main_lambda_package_file`
- `fetcher_lambda_package_file`
- `categorizer_image`
- VPC subnet IDs and security group IDs for ECS

Review `terraform.tfvars.example` in the target environment before planning.
