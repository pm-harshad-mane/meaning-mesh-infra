variable "environment" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "image" {
  type = string
}

variable "task_role_arn" {
  type = string
}

variable "execution_role_arn" {
  type = string
}

variable "environment_variables" {
  type = map(string)
}

variable "subnet_ids" {
  type = list(string)
}

variable "security_group_ids" {
  type = list(string)
}
