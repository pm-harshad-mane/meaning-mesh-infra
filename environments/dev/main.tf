module "dynamodb" {
  source      = "../../modules/dynamodb"
  environment = var.environment
}

module "sqs" {
  source      = "../../modules/sqs"
  environment = var.environment
}

module "iam" {
  source                       = "../../modules/iam"
  environment                  = var.environment
  url_categorization_table_arn = module.dynamodb.url_categorization_table_arn
  url_wip_table_arn            = module.dynamodb.url_wip_table_arn
  fetch_queue_arn              = module.sqs.fetch_queue_arn
  categorizer_queue_arn        = module.sqs.categorizer_queue_arn
}

module "lambda_main" {
  source       = "../../modules/lambda_main"
  environment  = var.environment
  role_arn     = module.iam.main_lambda_role_arn
  package_file = var.main_lambda_package_file
  environment_variables = {
    URL_CATEGORIZATION_TABLE = module.dynamodb.url_categorization_table_name
    URL_WIP_TABLE            = module.dynamodb.url_wip_table_name
    URL_FETCHER_QUEUE_URL    = module.sqs.fetch_queue_url
    URL_CACHE_TTL_SECONDS    = "2592000"
    URL_WIP_TTL_SECONDS      = "900"
    STRIP_TRACKING_PARAMS    = "true"
    LOG_LEVEL                = "INFO"
  }
}

module "lambda_fetcher" {
  source          = "../../modules/lambda_fetcher"
  environment     = var.environment
  role_arn        = module.iam.fetcher_lambda_role_arn
  package_file    = var.fetcher_lambda_package_file
  fetch_queue_arn = module.sqs.fetch_queue_arn
  environment_variables = {
    URL_CATEGORIZATION_TABLE  = module.dynamodb.url_categorization_table_name
    URL_WIP_TABLE             = module.dynamodb.url_wip_table_name
    URL_CATEGORIZER_QUEUE_URL = module.sqs.categorizer_queue_url
    FETCH_CONNECT_TIMEOUT_MS  = "2000"
    FETCH_READ_TIMEOUT_MS     = "7000"
    FETCH_TOTAL_TIMEOUT_MS    = "9000"
    UNKNOWN_CATEGORY_ID       = "UNKNOWN"
    UNKNOWN_CATEGORY_NAME     = "Unknown"
    MODEL_VERSION             = "bge-base-en-v1.5__bge-reranker-v2-m3"
    LOG_LEVEL                 = "INFO"
  }
}

module "api" {
  source               = "../../modules/api"
  environment          = var.environment
  lambda_invoke_arn    = module.lambda_main.invoke_arn
  lambda_function_name = module.lambda_main.function_name
}

module "ecs_categorizer" {
  source             = "../../modules/ecs_categorizer"
  environment        = var.environment
  aws_region         = var.aws_region
  image              = var.categorizer_image
  task_role_arn      = module.iam.categorizer_task_role_arn
  execution_role_arn = module.iam.categorizer_execution_role_arn
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids
  assign_public_ip   = true
  environment_variables = {
    AWS_REGION               = var.aws_region
    URL_CATEGORIZATION_TABLE = module.dynamodb.url_categorization_table_name
    URL_WIP_TABLE            = module.dynamodb.url_wip_table_name
    CATEGORIZER_QUEUE_URL    = module.sqs.categorizer_queue_url
    TAXONOMY_TSV_PATH        = "taxonomy/Content_Taxonomy_3.1_2.tsv"
    EMBED_MODEL_NAME         = "BAAI/bge-base-en-v1.5"
    RERANK_MODEL_NAME        = "BAAI/bge-reranker-v2-m3"
    TOP_K                    = "5"
    MODEL_VERSION            = "bge-base-en-v1.5__bge-reranker-v2-m3"
    LOG_LEVEL                = "INFO"
  }
}

module "monitoring" {
  source               = "../../modules/monitoring"
  environment          = var.environment
  fetch_dlq_name       = "url_fetcher_service_dlq"
  categorizer_dlq_name = "url_categorizer_service_dlq"
}
