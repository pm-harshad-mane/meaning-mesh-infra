# meaning-mesh-infra

Terraform infrastructure for Meaning-Mesh on AWS `us-east-1`.

Included modules:

- API Gateway HTTP API
- DynamoDB tables for `url_categorization` and `url_wip`
- SQS queues and DLQs
- Main Lambda
- Fetcher Lambda
- ECS categorizer service on ECS with EC2 Auto Scaling capacity
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

The categorizer module provisions ECS container instances in an Auto Scaling
group and runs the worker service on EC2 capacity instead of Fargate. The
default instance type is `m7g.4xlarge`, which is sized to run one
`16 vCPU / 32 GB` categorizer task per instance with headroom for the host.

Review `terraform.tfvars.example` in the target environment before planning.

## Dev Deployment Flow

Prerequisites:

- Docker with `buildx`
- AWS CLI authenticated to the target account
- Terraform 1.6+

Build deployable artifacts:

```bash
./scripts/build_dev_artifacts.sh <categorizer-ecr-image-uri>
```

Apply the `dev` environment:

```bash
./scripts/deploy_dev.sh \
  /absolute/path/to/meaning-mesh-main-service/dist/lambda.zip \
  /absolute/path/to/meaning-mesh-url-fetcher/dist/lambda.zip \
  <categorizer-ecr-image-uri> \
  subnet-abc123,subnet-def456 \
  sg-abc123
```

Report timing breakdowns for URLs that have already been processed:

```bash
./scripts/report_url_timings.py \
  "https://thehockeynews.com/nhl/boston-bruins/latest-news/bruins-linked-to-potential-summer-trade-for-rangers-star?probe=16384-20260414-a" \
  "https://versus.com/en/samsung-galaxy-a55-5g-vs-samsung-galaxy-a73-5g?probe=16384-20260414-a"
```

Notes:

- Categorizer timings come directly from DynamoDB.
- Main-service and fetcher timings are reconstructed from CloudWatch logs.
- The script matches pre-categorizer events by chronological alignment, so it is most reliable when you benchmark a small set of URLs together.
