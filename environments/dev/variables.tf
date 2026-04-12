variable "environment" {
  type    = string
  default = "dev"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "main_lambda_package_file" {
  type = string
}

variable "fetcher_lambda_package_file" {
  type = string
}

variable "categorizer_image" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "security_group_ids" {
  type = list(string)
}
